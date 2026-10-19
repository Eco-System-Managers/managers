import secrets
from datetime import date, timedelta

from django.contrib.auth.models import User
from django.core.mail import send_mail
from django.db import transaction
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.utils import get_md5_hash_password

from .models import CodigoRecuperacao


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
                domain=f'{schema_name}.localhost',
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

    def recuperar(self, email: str) -> str:
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return self.GENERIC_MSG

        CodigoRecuperacao.objects.filter(user=user, usado=False).update(usado=True)

        codigo = ''.join(secrets.choice('0123456789') for _ in range(8))
        CodigoRecuperacao.objects.create(user=user, codigo=codigo)

        send_mail(
            subject='Código de recuperação — Work Manage',
            message=f'Seu código de recuperação é: {codigo}\n\nEle expira em 15 minutos.',
            from_email=None,
            recipient_list=[email],
        )

        return self.GENERIC_MSG


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
