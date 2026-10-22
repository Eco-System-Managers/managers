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
