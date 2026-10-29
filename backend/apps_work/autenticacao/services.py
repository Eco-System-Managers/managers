from datetime import date, timedelta

from django.conf import settings
from django.contrib.auth.hashers import make_password
from django.contrib.auth.models import User
from django.db import transaction
from django.utils import timezone
from django_tenants.utils import get_public_schema_name, schema_context
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.utils import get_md5_hash_password

from core.email import enviar_email
from core.excecoes import ErroDeNegocio
from core.limites import login_work
from core.recuperacao import RecuperacaoSenhaBase

from .serializers import gerar_schema_name
from .models import CadastroPendente, CodigoCadastro, CodigoRecuperacao, UltimaAtividade


def dominio_do_schema(schema_name: str) -> str:
    """Subdomínio do tenant. O schema usa `_`, que é inválido em nome de host
    (o Django recusa a requisição); no domínio ele vira `-`."""
    return f"{schema_name.replace('_', '-')}.{settings.TENANT_DOMAIN_SUFFIX}"


class OnboardingService:
    def registrar_empresa(
        self,
        nome_empresa: str,
        schema_name: str,
        nome: str,
        email: str,
        senha: str | None = None,
        senha_hash: str | None = None,
    ):
        """Cria a empresa e o dono. A senha vem em claro (cadastro direto) ou
        já em hash (confirmação de cadastro, que nunca guardou a senha em claro)."""
        from django.db import connection
        from tenants.models import Domain, Papel, Tenant, Membro

        # schema_context volta ao schema de quem chamou ao sair, inclusive em
        # erro. Dentro, a criação do tenant deixa a conexão no schema novo (ao
        # rodar as migrations dele) — daí a volta explícita ao público.
        with schema_context(get_public_schema_name()), transaction.atomic():
            tenant = Tenant.objects.create(schema_name=schema_name, nome=nome_empresa)
            connection.set_schema_to_public()
            Domain.objects.create(
                domain=dominio_do_schema(schema_name),
                tenant=tenant,
                is_primary=True,
            )
            email = email.lower().strip()
            user = User.objects.create_user(username=email, email=email, first_name=nome)
            user.password = senha_hash or make_password(senha)
            user.save(update_fields=['password'])
            Membro.objects.create(user=user, tenant=tenant, papel=Papel.PROPRIETARIO)

            from apps_work.billing.models import Assinatura, StatusAssinatura
            from apps_work.billing.services import plano_padrao

            Assinatura.objects.create(
                tenant=tenant,
                plano=plano_padrao(),
                status=StatusAssinatura.TRIAL,
                inicio=date.today(),
                trial_fim=date.today() + timedelta(days=28),
                proximo_vencimento=date.today() + timedelta(days=28),
            )

        # Começa o relógio de inatividade junto com a conta.
        UltimaAtividade.objects.create(user=user, ultimo_acesso=timezone.now())
        return user, tenant


class ConfirmacaoCadastroService:
    """Cadastro em duas etapas: os dados ficam pendentes até o dono provar que
    o e-mail é dele com o código enviado para lá.

    Só a confirmação cria a empresa (`OnboardingService`). Sem ela, qualquer um
    criaria empresas em nome de e-mails de terceiros, e cada tentativa custaria
    um schema inteiro.
    """

    MENSAGEM = 'Enviamos um código de confirmação para o seu e-mail.'
    # Pendente esquecido some no próximo cadastro de qualquer pessoa; o código
    # já expira em 15 minutos, então um dia é folga de sobra para reenviar.
    VALIDADE_PENDENTE = timedelta(days=1)

    def solicitar(self, nome_empresa: str, nome: str, email: str, senha: str) -> None:
        """Guarda o cadastro e envia o código. Pedir de novo com o mesmo e-mail
        substitui os dados e invalida o código anterior."""
        with schema_context(get_public_schema_name()):
            CadastroPendente.objects.filter(criado_em__lt=timezone.now() - self.VALIDADE_PENDENTE).delete()
            pendente, _ = CadastroPendente.objects.update_or_create(
                email=email.strip().lower(),
                defaults={'nome_empresa': nome_empresa, 'nome': nome, 'senha_hash': make_password(senha)},
            )
            self._enviar_codigo(pendente)

    def reenviar(self, email: str) -> None:
        """Novo código para um cadastro pendente. Sem pendente, não faz nada —
        e responde igual, para não dizer quem está se cadastrando."""
        with schema_context(get_public_schema_name()):
            pendente = CadastroPendente.objects.filter(email=email.strip().lower()).first()
            if pendente is not None:
                self._enviar_codigo(pendente)

    def confirmar(self, email: str, codigo: str):
        """Confere o código e cria a empresa. Devolve (user, tenant)."""
        email = email.strip().lower()
        with schema_context(get_public_schema_name()):
            # A tentativa errada precisa ficar gravada, por isso o erro sai
            # depois da transação — senão o limite de tentativas nunca chegaria.
            with transaction.atomic():
                # Trava o pendente: dois confirmares simultâneos criariam a
                # empresa duas vezes.
                pendente = CadastroPendente.objects.select_for_update().filter(email=email).first()
                registro = self._codigo_vigente(pendente)
                confere = registro is not None and registro.confere(codigo)
                if registro is not None and not confere:
                    registro.tentativas += 1
                    registro.save(update_fields=['tentativas'])
                elif confere:
                    # O e-mail pode ter virado conta pelo cadastro direto
                    # enquanto o código esperava.
                    em_uso = User.objects.filter(username=email).exists()
                    if not em_uso:
                        user, tenant = OnboardingService().registrar_empresa(
                            nome_empresa=pendente.nome_empresa,
                            schema_name=gerar_schema_name(pendente.nome_empresa),
                            nome=pendente.nome,
                            email=email,
                            senha_hash=pendente.senha_hash,
                        )
                    pendente.delete()
            if not confere:
                raise ErroDeNegocio('Código inválido ou expirado.', 'codigo_invalido')
            if em_uso:
                raise ErroDeNegocio('Este e-mail já está em uso.', 'email_em_uso')
        return user, tenant

    def _codigo_vigente(self, pendente):
        if pendente is None:
            return None
        registro = pendente.codigos.filter(usado=False).first()
        if registro is None or registro.expirado or registro.bloqueado:
            return None
        return registro

    def _enviar_codigo(self, pendente: CadastroPendente) -> None:
        _, codigo = CodigoCadastro.emitir(pendente)
        enviar_email.enqueue(
            assunto='Confirme seu cadastro — Work Manage',
            mensagem=(
                f'Olá, {pendente.nome}!\n\n'
                f'Seu código para confirmar o cadastro de {pendente.nome_empresa} é: {codigo}\n\n'
                'Ele expira em 15 minutos.'
            ),
            destinatario=pendente.email,
        )


class LoginService:
    def autenticar(self, email: str, senha: str):
        """Confere as credenciais e devolve (user, tenant).

        Levanta ErroDeNegocio com o status da resposta: 429 com 10 falhas em
        15 minutos para o e-mail, 401 para credencial errada, 403 para usuário
        desativado e 400 para quem não pertence a nenhuma empresa.
        """
        from tenants.models import Membro

        email = email.strip().lower()
        login_work.verificar(email)

        user = User.objects.filter(username=email).first()
        if user is None:
            # Calcula um hash mesmo assim: sem isso, e-mail inexistente responde
            # mais rápido e o tempo de resposta revela quem tem conta.
            User().set_password(senha)
        if user is None or not user.check_password(senha):
            login_work.registrar_falha(email)
            raise ErroDeNegocio('E-mail ou senha inválidos.', 'credenciais_invalidas', 401)
        login_work.limpar(email)

        if not user.is_active:
            raise ErroDeNegocio(
                'Você está inativo. Entre em contato com o proprietário do sistema.', 'conta_inativa', 403,
            )

        membro = Membro.objects.filter(user=user).select_related('tenant').first()
        if membro is None:
            raise ErroDeNegocio('Usuário não vinculado a nenhuma empresa.', 'sem_empresa')

        # Entrar de novo dentro do prazo desiste da exclusão. A equipe de um
        # negócio que o dono mandou excluir não entra mais.
        exclusao = ExclusaoContaService()
        exclusao.desistir_ao_entrar(user)
        if exclusao.negocio_em_exclusao(membro.tenant.schema_name):
            raise ErroDeNegocio(
                'Este negócio está sendo encerrado pelo proprietário.', 'negocio_em_exclusao', 403,
            )

        UltimaAtividade.objects.update_or_create(user=user, defaults={'ultimo_acesso': timezone.now()})
        return user, membro.tenant


class RecuperacaoSenhaService(RecuperacaoSenhaBase):
    modelo_codigo = CodigoRecuperacao
    nome_produto = 'Work Manage'

    def _dono(self, email: str):
        # O username guarda o e-mail e é único; o campo email do User não é.
        return User.objects.filter(username=email.strip().lower()).first()

    def _encerrar_sessoes(self, user) -> None:
        SessaoService().encerrar_todas(user)


class SessaoInvalida(Exception):
    """Refresh que não pode mais ser usado: expirado, revogado, de usuário
    inativo ou removido, com senha trocada ou sem vínculo com o tenant."""


class SessaoService:
    """Emissão, renovação e revogação das sessões do Work Manage.

    Cada refresh vale uma vez: renovar revoga o anterior e devolve outro. O
    access não é revogado um a um — dura no máximo uma hora — mas o hash da
    senha gravado nele (`CHECK_REVOKE_TOKEN`) o invalida na troca de senha.
    """

    def emitir(self, user, tenant) -> RefreshToken:
        refresh = RefreshToken.for_user(user)
        refresh['schema_name'] = tenant.schema_name
        refresh['empresa'] = tenant.nome
        return refresh

    def renovar(self, token_str: str) -> RefreshToken:
        from tenants.models import Tenant, Membro

        try:
            # Valida assinatura, expiração, audiência e se já foi revogado.
            antigo = RefreshToken(token_str)
        except TokenError:
            raise SessaoInvalida()

        user = User.objects.filter(pk=antigo.get(api_settings.USER_ID_CLAIM)).first()
        if user is None or not user.is_active:
            raise SessaoInvalida()
        if antigo.get(api_settings.REVOKE_TOKEN_CLAIM) != get_md5_hash_password(user.password):
            raise SessaoInvalida()

        schema_name = antigo.get('schema_name')
        if not schema_name or Membro.papel_no_schema(user, schema_name) is None:
            raise SessaoInvalida()
        if ExclusaoContaService().conta_travada(user, schema_name):
            raise SessaoInvalida()

        antigo.blacklist()
        return self.emitir(user, Tenant.objects.get(schema_name=schema_name))

    def encerrar(self, token_str: str) -> None:
        """Revoga um refresh. Token inválido ou já revogado é ignorado: o
        logout precisa funcionar mesmo com uma sessão que já acabou."""
        try:
            RefreshToken(token_str).blacklist()
        except TokenError:
            pass

    def encerrar_todas(self, user) -> None:
        """Revoga todos os refresh do usuário — troca de senha e desativação."""
        pendentes = OutstandingToken.objects.filter(user=user, blacklistedtoken__isnull=True)
        BlacklistedToken.objects.bulk_create(
            [BlacklistedToken(token=token) for token in pendentes],
            ignore_conflicts=True,
        )


class ExclusaoContaService:
    """Excluir a conta pelo app: o pedido, a desistência e a exclusão de vez.

    O pedido trava a conta na hora e marca a exclusão para daqui a
    `PRAZO_DIAS`. Do dono, é o negócio inteiro: a vitrine sai do ar, a equipe
    perde o acesso e, no fim do prazo, o schema é apagado. Da equipe, é só o
    login: o nome continua nos atendimentos e no caixa, que são do negócio.
    Entrar de novo dentro do prazo desiste do pedido.
    """

    PRAZO_DIAS = 30

    @transaction.atomic
    def solicitar(self, user, schema_name: str, senha: str):
        from apps_serv.vitrine.models import NegocioPublico
        from tenants.models import Membro, Papel, Tenant

        from .models import ExclusaoConta

        if not user.check_password(senha):
            raise ErroDeNegocio('Senha incorreta.', 'senha_incorreta')

        apaga_negocio = Membro.papel_no_schema(user, schema_name) == Papel.PROPRIETARIO
        if apaga_negocio:
            self._cancelar_cobranca(Tenant.objects.get(schema_name=schema_name))
            NegocioPublico.objects.filter(schema_name=schema_name).update(ativo=False)

        exclusao, _ = ExclusaoConta.objects.update_or_create(
            user=user,
            defaults={
                'schema_name': schema_name,
                'apaga_negocio': apaga_negocio,
                'excluir_em': timezone.now() + timedelta(days=self.PRAZO_DIAS),
            },
        )

        sessoes = SessaoService()
        if apaga_negocio:
            for membro in Membro.objects.filter(tenant__schema_name=schema_name).select_related('user'):
                sessoes.encerrar_todas(membro.user)
        else:
            sessoes.encerrar_todas(user)
        return exclusao

    def desistir_ao_entrar(self, user) -> bool:
        """Chamado no login: quem pediu e entrou de novo desistiu. O negócio
        do dono volta para a vitrine (se estava publicado antes)."""
        from apps_serv.vitrine.services import SincronizarVitrineService

        from .models import ExclusaoConta

        exclusao = ExclusaoConta.objects.filter(user=user).first()
        if exclusao is None:
            return False
        exclusao.delete()
        if exclusao.apaga_negocio:
            with schema_context(exclusao.schema_name):
                from apps_work.empresa.models import EmpresaConfig
                config = EmpresaConfig.objects.filter(pk=1).first()
            if config is not None:
                SincronizarVitrineService().sincronizar(exclusao.schema_name, config)
        return True

    def negocio_em_exclusao(self, schema_name: str) -> bool:
        from .models import ExclusaoConta

        return ExclusaoConta.objects.filter(schema_name=schema_name, apaga_negocio=True).exists()

    def conta_travada(self, user, schema_name: str) -> bool:
        """A conta não entra mais: pediu a exclusão, ou o dono pediu a do negócio."""
        from .models import ExclusaoConta

        return ExclusaoConta.objects.filter(user=user).exists() or self.negocio_em_exclusao(schema_name)

    def excluir_vencidas(self, agora=None) -> int:
        """Apaga de vez os pedidos com o prazo vencido. Um que falha não segura
        os outros: fica para a próxima rodada."""
        import logging

        from .models import ExclusaoConta

        logger = logging.getLogger(__name__)
        vencidas = ExclusaoConta.objects.filter(excluir_em__lte=agora or timezone.now()).select_related('user')
        feitas = 0
        for exclusao in vencidas:
            try:
                if exclusao.apaga_negocio:
                    self._apagar_negocio(exclusao.schema_name)
                else:
                    self._apagar_login(exclusao.user)
                feitas += 1
            except Exception:
                logger.exception('Falha ao excluir a conta', extra={'schema_name': exclusao.schema_name})
        return feitas

    def _cancelar_cobranca(self, tenant) -> None:
        """Quem paga recorrência precisa parar de ser cobrado antes de o negócio
        sumir. Se o gateway falhar, o pedido não segue."""
        from apps_work.billing.models import Assinatura, StatusAssinatura
        from apps_work.billing.services import AssinaturaGatewayError, gateway_de_pagamento

        assinatura = Assinatura.objects.filter(tenant=tenant).first()
        if assinatura is None or assinatura.status != StatusAssinatura.ATIVA or not assinatura.id_externo:
            return
        try:
            gateway_de_pagamento().cancelar_assinatura(tenant)
        except AssinaturaGatewayError as e:
            raise ErroDeNegocio(str(e), 'assinatura_nao_cancelada')

    def _desligar_da_equipe(self, user, schema_name: str) -> None:
        """O colaborador fica sem login, com o nome guardado e inativo: o
        histórico do negócio continua mostrando quem atendeu."""
        from apps_work.usuarios.models import Colaborador

        for colaborador in Colaborador.objects.filter(user=user):
            colaborador.nome = colaborador.nome_exibido
            colaborador.user = None
            colaborador.ativo = False
            colaborador.save(update_fields=['nome', 'user', 'ativo'])

    @transaction.atomic
    def _apagar_login(self, user) -> None:
        from tenants.models import Membro

        membros = list(Membro.objects.filter(user=user).select_related('tenant'))
        for membro in membros:
            with schema_context(membro.tenant.schema_name):
                self._desligar_da_equipe(user, membro.tenant.schema_name)
        Membro.objects.filter(user=user).delete()
        # O User tem relação com tabelas dos tenants (Colaborador): apagar
        # dentro de um schema de negócio deixa o Django enxergar essa tabela.
        if membros:
            with schema_context(membros[0].tenant.schema_name):
                user.delete()
        else:
            user.delete()

    @transaction.atomic
    def _apagar_negocio(self, schema_name: str) -> None:
        from apps_serv.consumidores.models import AgendamentoConsumidor, VinculoConsumidor
        from apps_serv.vitrine.models import NegocioPublico
        from apps_work.agenda.models import StatusAgendamento
        from tenants.models import ConviteIndex, Membro, Tenant

        from .models import ExclusaoConta

        tenant = Tenant.objects.get(schema_name=schema_name)
        usuarios = [m.user for m in Membro.objects.filter(tenant=tenant).select_related('user')]

        with schema_context(schema_name):
            from apps_work.usuarios.models import Colaborador
            Colaborador.objects.update(user=None)
            Membro.objects.filter(tenant=tenant).delete()
            # Quem só estava neste negócio perde o login junto; quem está em
            # outro continua lá.
            for user in usuarios:
                if not Membro.objects.filter(user=user).exists():
                    user.delete()

        # O app do cliente: os horários que ainda iam acontecer viram cancelados
        # e o negócio sai da lista dele. O histórico de cada cliente fica.
        AgendamentoConsumidor.objects.filter(
            schema_name=schema_name,
            status__in=[StatusAgendamento.AGENDADO, StatusAgendamento.CONFIRMADO],
        ).update(status=StatusAgendamento.CANCELADO)
        VinculoConsumidor.objects.filter(schema_name=schema_name).delete()
        NegocioPublico.objects.filter(schema_name=schema_name).delete()
        ConviteIndex.objects.filter(schema_name=schema_name).delete()
        # O dono que está em outro negócio continua com o login: o pedido sai
        # daqui, senão voltaria na próxima rodada.
        ExclusaoConta.objects.filter(schema_name=schema_name).delete()

        with schema_context(get_public_schema_name()):
            tenant.delete(force_drop=True)
