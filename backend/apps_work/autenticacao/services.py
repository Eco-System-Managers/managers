import secrets
from datetime import date, timedelta

from django.contrib.auth.models import User
from django.core.mail import send_mail
from django.db import transaction

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
