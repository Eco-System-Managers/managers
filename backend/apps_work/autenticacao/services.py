from datetime import date, timedelta

from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import transaction
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.utils import get_md5_hash_password

from core.email import enviar_email

from .models import CodigoRecuperacao
from core.excecoes import ErroDeNegocio


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
        from tenants.models import Domain, Tenant, UserTenant

        with transaction.atomic():
            connection.set_schema_to_public()
            tenant = Tenant.objects.create(schema_name=schema_name, name=nome_empresa)
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
            UserTenant.objects.create(user=user, tenant=tenant, role='proprietario')

            from apps_work.billing.models import Assinatura, Plano

            plano_pro = Plano.objects.filter(nome='pro', ativo=True).first()
            if plano_pro:
                Assinatura.objects.create(
                    tenant=tenant,
                    plano=plano_pro,
                    status='trial',
                    inicio=date.today(),
                    trial_fim=date.today() + timedelta(days=28),
                    proximo_vencimento=date.today() + timedelta(days=28),
                )

        return user, tenant


class RecuperacaoSenhaService:
    GENERIC_MSG = 'Se este e-mail estiver cadastrado, você receberá um código em instantes.'

    def _usuario(self, email: str):
        # O username guarda o e-mail e é único; o campo email do User não é.
        return User.objects.filter(username=email.strip().lower()).first()

    def _codigo_vigente(self, user):
        registro = CodigoRecuperacao.objects.filter(user=user, usado=False).first()
        if registro is None or registro.expirado or registro.bloqueado:
            return None
        return registro

    def _conferir(self, registro, codigo: str) -> bool:
        if registro.confere(codigo):
            return True
        registro.tentativas += 1
        registro.save(update_fields=['tentativas'])
        return False

    def recuperar(self, email: str) -> str:
        user = self._usuario(email)
        if user is None:
            return self.GENERIC_MSG

        _, codigo = CodigoRecuperacao.emitir(user)
        enviar_email.enqueue(
            assunto='Código de recuperação — Work Manage',
            mensagem=f'Seu código de recuperação é: {codigo}\n\nEle expira em 15 minutos.',
            destinatario=user.email,
        )
        return self.GENERIC_MSG

    def verificar_codigo(self, email: str, codigo: str) -> bool:
        user = self._usuario(email)
        registro = self._codigo_vigente(user) if user else None
        return registro is not None and self._conferir(registro, codigo)

    def redefinir_senha(self, email: str, codigo: str, nova_senha: str) -> None:
        # Sem transação: a tentativa errada precisa ficar gravada mesmo com o
        # ValueError — senão o limite de tentativas nunca seria atingido.
        user = self._usuario(email)

        # A senha é validada antes de gastar uma tentativa do código.
        try:
            validate_password(nova_senha, user)
        except DjangoValidationError as e:
            raise ErroDeNegocio(' '.join(e.messages), 'senha_fraca')

        registro = self._codigo_vigente(user) if user else None
        if registro is None or not self._conferir(registro, codigo):
            raise ErroDeNegocio('Código inválido ou expirado.', 'codigo_invalido')

        user.set_password(nova_senha)
        user.save(update_fields=['password'])
        registro.usado = True
        registro.save(update_fields=['usado'])
        # Quem pediu a recuperação pode estar tirando um invasor da conta.
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
        refresh['empresa'] = tenant.name
        return refresh

    def renovar(self, token_str: str) -> RefreshToken:
        from tenants.models import Tenant, UserTenant

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
        if not schema_name or UserTenant.papel_no_schema(user, schema_name) is None:
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
