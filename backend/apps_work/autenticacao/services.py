from datetime import date, timedelta

from django.conf import settings
from django.contrib.auth.models import User
from django.db import transaction
from django.utils import timezone
from django_tenants.utils import get_public_schema_name, schema_context
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.utils import get_md5_hash_password

from core.excecoes import ErroDeNegocio
from core.limites import login_work
from core.recuperacao import RecuperacaoSenhaBase

from .models import CodigoRecuperacao, UltimaAtividade


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
        senha: str,
    ):
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
            user = User.objects.create_user(
                username=email,
                email=email,
                password=senha,
                first_name=nome,
            )
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
