import uuid

from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import connection, transaction
from django.utils import timezone
from django_tenants.utils import schema_context
from datetime import timedelta
from tenants.models import Papel, Tenant, Membro
from apps_work.autenticacao.models import UltimaAtividade
from core.email import enviar_email
from core.links import link_convite
from .models import Colaborador, ConviteColaborador
from core.excecoes import ErroDeNegocio


class ColaboradorService:
    # Quem não tem login não tem is_active para sincronizar nem sessão para
    # encerrar: os métodos abaixo toleram `user` nulo.
    def sincronizar_is_active(self, colaborador: Colaborador) -> None:
        if colaborador.user_id is None:
            return
        colaborador.user.is_active = colaborador.ativo
        colaborador.user.save(update_fields=['is_active'])

    def _garantir_que_nao_e_proprietario(self, colaborador: Colaborador) -> None:
        # Desativar ou remover o dono — inclusive ele mesmo — deixaria o tenant
        # sem ninguém capaz de reativá-lo.
        if colaborador.user_id is None:
            return
        if Membro.papel_no_schema(colaborador.user, connection.schema_name) == Papel.PROPRIETARIO:
            raise ErroDeNegocio('O proprietário não pode ser desativado nem removido.', 'proprietario_protegido')

    def desativar(self, colaborador: Colaborador) -> None:
        self._garantir_que_nao_e_proprietario(colaborador)
        colaborador.ativo = False
        colaborador.save(update_fields=['ativo'])
        self.sincronizar_is_active(colaborador)
        colaborador.servicos.clear()
        if colaborador.user_id is not None:
            # Sem isso, reativar devolveria a validade aos refresh antigos.
            from apps_work.autenticacao.services import SessaoService
            SessaoService().encerrar_todas(colaborador.user)

    def reativar(self, colaborador: Colaborador) -> None:
        colaborador.ativo = True
        colaborador.save(update_fields=['ativo'])
        self.sincronizar_is_active(colaborador)

    def tem_agendamentos_pendentes(self, colaborador: Colaborador) -> dict:
        from apps_work.agenda.models import Agendamento, StatusAgendamento
        total = Agendamento.objects.filter(
            colaborador=colaborador,
            data_hora__gte=timezone.now(),
        ).exclude(status__in=[StatusAgendamento.CONCLUIDO, StatusAgendamento.CANCELADO, StatusAgendamento.FALTOU]).count()
        return {'tem_pendentes': total > 0, 'total': total}

    @transaction.atomic
    def remover(self, colaborador: Colaborador) -> None:
        from apps_work.agenda.models import Agendamento
        from apps_work.kanban.models import AtendimentoKanban
        self._garantir_que_nao_e_proprietario(colaborador)
        user = colaborador.user
        # o histórico fica, sem profissional
        Agendamento.objects.filter(colaborador=colaborador).update(colaborador=None)
        AtendimentoKanban.objects.filter(colaborador=colaborador).update(colaborador=None)
        colaborador.delete()
        if user is not None:
            Membro.objects.filter(user=user).delete()
            UltimaAtividade.objects.filter(user=user).delete()
            user.delete()


class ConviteService:
    EXPIRACAO_DIAS = 2

    def localizar(self, token):
        """Acha o convite pelo token, sem saber de antemão em que tenant ele está.

        O ConviteIndex (schema público) diz o schema; a leitura do convite roda
        num `schema_context`, que volta ao schema anterior mesmo se falhar.
        Devolve (tenant, convite) ou levanta 404.
        """
        from tenants.models import ConviteIndex

        # A rota é pública e o token vem da URL. Fora do formato UUID, o ORM
        # levantaria ValidationError (500); para quem colou o link errado é 404.
        try:
            token = uuid.UUID(str(token))
        except ValueError:
            raise ErroDeNegocio('Convite não encontrado.', 'convite_nao_encontrado', 404)

        index = ConviteIndex.objects.filter(token=token).first()
        tenant = Tenant.objects.filter(schema_name=index.schema_name).first() if index else None
        if tenant is None:
            raise ErroDeNegocio('Convite não encontrado.', 'convite_nao_encontrado', 404)
        with schema_context(tenant.schema_name):
            convite = ConviteColaborador.objects.filter(token=token).first()
        if convite is None:
            raise ErroDeNegocio('Convite não encontrado.', 'convite_nao_encontrado', 404)
        return tenant, convite

    def info(self, token) -> dict:
        """O que a tela de aceite mostra antes de a pessoa definir a senha."""
        _, convite = self.localizar(token)
        if convite.aceito:
            raise ErroDeNegocio('Convite não encontrado ou já utilizado.', 'convite_ja_aceito', 404)
        if convite.expira_em < timezone.now():
            raise ErroDeNegocio('Este convite expirou.', 'convite_expirado')
        return {'nome': convite.nome, 'email': convite.email, 'expira_em': convite.expira_em}

    def cancelar(self, convite: ConviteColaborador) -> None:
        from tenants.models import ConviteIndex
        ConviteIndex.objects.filter(token=convite.token).delete()
        convite.delete()

    def criar_e_enviar(
        self, nome: str, email: str, tenant_nome: str, colaborador: Colaborador | None = None,
    ) -> ConviteColaborador:
        """Convida por e-mail. Com `colaborador`, é dar login a quem já está na equipe."""
        from tenants.models import ConviteIndex
        email = email.lower().strip()
        if colaborador is not None and colaborador.tem_acesso:
            raise ErroDeNegocio('Esta pessoa já tem acesso ao app.', 'colaborador_com_acesso')
        if User.objects.filter(email=email).exists():
            raise ErroDeNegocio('Este e-mail já está vinculado a uma conta.', 'email_ja_cadastrado')
        if ConviteColaborador.objects.filter(email=email, aceito=False, expira_em__gt=timezone.now()).exists():
            raise ErroDeNegocio('Já existe um convite pendente para este e-mail.', 'convite_pendente')
        expira_em = timezone.now() + timedelta(days=self.EXPIRACAO_DIAS)
        convite = ConviteColaborador.objects.create(
            nome=nome, email=email, expira_em=expira_em, colaborador=colaborador,
        )
        ConviteIndex.objects.create(token=convite.token, schema_name=connection.schema_name)
        self._enviar_email(convite, tenant_nome)
        return convite

    def _enviar_email(self, convite, tenant_nome: str) -> None:
        link = link_convite(convite.token)
        saudacao = f'Olá, {convite.nome}!' if convite.nome else 'Olá!'
        enviar_email.enqueue(
            assunto=f'Você foi convidado para o {tenant_nome} — Work Manage',
            mensagem=(
                f'{saudacao}\n\n'
                f'Você foi convidado para fazer parte da equipe {tenant_nome} no Work Manage.\n\n'
                f'Clique no link abaixo para criar sua senha e acessar o sistema:\n'
                f'{link}\n\n'
                f'Este link expira em {self.EXPIRACAO_DIAS} dias.'
            ),
            destinatario=convite.email,
        )


class AceitarConviteService:
    def aceitar(self, token, senha: str):
        """Cria a conta do convidado e devolve a sessão (RefreshToken).

        Tudo roda no schema do tenant do convite (`schema_context` restaura o
        anterior, inclusive em erro). As tabelas compartilhadas — User, Membro,
        UltimaAtividade, ConviteIndex — ficam no público, que está no
        search_path de todo tenant, então não é preciso trocar de schema.
        """
        from tenants.models import ConviteIndex

        tenant, _ = ConviteService().localizar(token)
        if not senha.strip():
            raise ErroDeNegocio('A senha é obrigatória.', 'senha_obrigatoria')

        with schema_context(tenant.schema_name), transaction.atomic():
            # Trava o convite: dois aceites simultâneos passariam pela checagem
            # de `aceito` e o segundo terminaria em IntegrityError no User.
            convite = ConviteColaborador.objects.select_for_update().get(token=token)
            if convite.aceito:
                raise ErroDeNegocio('Convite já foi aceito.', 'convite_ja_aceito')
            self._validar_senha(senha)
            self._validar_expiracao(convite)
            if User.objects.filter(email=convite.email).exists():
                raise ErroDeNegocio('Este e-mail já está vinculado a uma conta.', 'email_ja_cadastrado')

            partes = convite.nome.strip().split(' ', 1) if convite.nome else []
            user = User.objects.create_user(
                username=convite.email,
                email=convite.email,
                password=senha,
                first_name=partes[0] if partes else '',
                last_name=partes[1] if len(partes) > 1 else '',
            )
            Membro.objects.create(user=user, tenant=tenant, papel=Papel.COLABORADOR)
            UltimaAtividade.objects.create(user=user, ultimo_acesso=timezone.now())
            if convite.colaborador_id:
                # quem já estava na equipe ganha o login no mesmo registro
                colaborador = convite.colaborador
                colaborador.user = user
                colaborador.ativo = True
                colaborador.save(update_fields=['user', 'ativo'])
            else:
                Colaborador.objects.create(user=user, nome=convite.nome.strip(), ativo=True)

            convite.aceito = True
            convite.save(update_fields=['aceito'])
            ConviteIndex.objects.filter(token=convite.token).delete()

        return self._gerar_tokens(user, tenant)

    def _validar_senha(self, senha: str) -> None:
        try:
            validate_password(senha)
        except DjangoValidationError as e:
            raise ErroDeNegocio(' '.join(e.messages), 'senha_fraca')

    def _validar_expiracao(self, convite) -> None:
        if convite.expira_em < timezone.now():
            raise ErroDeNegocio('Este convite expirou.', 'convite_expirado')

    def _gerar_tokens(self, user, tenant):
        from apps_work.autenticacao.services import SessaoService
        return SessaoService().emitir(user, tenant)
