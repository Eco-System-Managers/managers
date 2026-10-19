from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.mail import send_mail
from django.db import connection, transaction
from django.utils import timezone
from datetime import timedelta
from rest_framework_simplejwt.tokens import RefreshToken
from tenants.models import Tenant, UserTenant
from apps_work.autenticacao.models import LastActivity
from .models import Colaborador, ConviteColaborador


class ColaboradorService:
    def sincronizar_is_active(self, colaborador: Colaborador) -> None:
        colaborador.user.is_active = colaborador.ativo
        colaborador.user.save(update_fields=['is_active'])

    def desativar(self, colaborador: Colaborador) -> None:
        colaborador.ativo = False
        colaborador.save(update_fields=['ativo'])
        self.sincronizar_is_active(colaborador)
        colaborador.servicos.clear()

    def reativar(self, colaborador: Colaborador) -> None:
        colaborador.ativo = True
        colaborador.save(update_fields=['ativo'])
        self.sincronizar_is_active(colaborador)

    def tem_agendamentos_pendentes(self, colaborador: Colaborador) -> dict:
        from apps_work.agenda.models import Agendamento
        total = Agendamento.objects.filter(
            colaborador=colaborador,
            data_hora__gte=timezone.now(),
        ).exclude(status__in=['concluido', 'cancelado', 'faltou']).count()
        return {'tem_pendentes': total > 0, 'total': total}

    @transaction.atomic
    def remover(self, colaborador: Colaborador) -> None:
        from apps_work.agenda.models import Agendamento
        user = colaborador.user
        Agendamento.objects.filter(colaborador=colaborador).update(colaborador=None)
        colaborador.delete()
        UserTenant.objects.filter(user=user).delete()
        LastActivity.objects.filter(user=user).delete()
        user.delete()


class ConviteService:
    EXPIRACAO_DIAS = 2

    def criar_e_enviar(self, nome: str, email: str, tenant_nome: str) -> ConviteColaborador:
        from apps_work.empresa.models import EmpresaConfig
        from tenants.models import ConviteIndex
        email = email.lower().strip()
        config = EmpresaConfig.objects.filter(pk=1).first()
        if config and config.tipo_agenda == 'kanban':
            raise ValueError('Empresas com agenda por esteira não podem ter colaboradores.')
        if User.objects.filter(email=email).exists():
            raise ValueError('Este e-mail já está vinculado a uma conta.')
        if ConviteColaborador.objects.filter(email=email, aceito=False, expira_em__gt=timezone.now()).exists():
            raise ValueError('Já existe um convite pendente para este e-mail.')
        expira_em = timezone.now() + timedelta(days=self.EXPIRACAO_DIAS)
        convite = ConviteColaborador.objects.create(nome=nome, email=email, expira_em=expira_em)
        ConviteIndex.objects.create(token=convite.token, schema_name=connection.schema_name)
        self._enviar_email(convite, tenant_nome)
        return convite

    def _enviar_email(self, convite, tenant_nome: str) -> None:
        link = f'{settings.FRONTEND_URL}/convite/{convite.token}'
        saudacao = f'Olá, {convite.nome}!' if convite.nome else 'Olá!'
        send_mail(
            subject=f'Você foi convidado para o {tenant_nome} — Work Manage',
            message=(
                f'{saudacao}\n\n'
                f'Você foi convidado para fazer parte da equipe {tenant_nome} no Work Manage.\n\n'
                f'Clique no link abaixo para criar sua senha e acessar o sistema:\n'
                f'{link}\n\n'
                f'Este link expira em {self.EXPIRACAO_DIAS} dias.'
            ),
            from_email=None,
            recipient_list=[convite.email],
        )


class AceitarConviteService:
    @transaction.atomic
    def aceitar(self, convite, senha: str) -> dict:
        self._validar_senha(senha)
        self._validar_expiracao(convite)

        current_schema = connection.schema_name
        connection.set_schema_to_public()
        tenant = Tenant.objects.get(schema_name=current_schema)

        try:
            if User.objects.filter(email=convite.email).exists():
                raise ValueError('Este e-mail já está vinculado a uma conta.')

            partes = convite.nome.strip().split(' ', 1) if convite.nome else []
            user = User.objects.create_user(
                username=convite.email,
                email=convite.email,
                password=senha,
                first_name=partes[0] if partes else '',
                last_name=partes[1] if len(partes) > 1 else '',
            )
            UserTenant.objects.create(user=user, tenant=tenant, role='colaborador')
            LastActivity.objects.create(user=user, ultimo_acesso=timezone.now())

            connection.set_tenant(tenant)

            Colaborador.objects.create(user=user, role='colaborador', ativo=True)

            convite.aceito = True
            convite.save()

            from tenants.models import ConviteIndex
            ConviteIndex.objects.filter(token=convite.token).delete()

            return self._gerar_tokens(user, tenant)
        except Exception:
            connection.set_tenant(tenant)
            raise

    def _validar_senha(self, senha: str) -> None:
        try:
            validate_password(senha)
        except DjangoValidationError as e:
            raise ValueError(' '.join(e.messages))

    def _validar_expiracao(self, convite) -> None:
        if convite.expira_em < timezone.now():
            raise ValueError('Este convite expirou.')

    def _gerar_tokens(self, user, tenant) -> dict:
        refresh = RefreshToken.for_user(user)
        refresh['schema_name'] = tenant.schema_name
        refresh['empresa'] = tenant.name
        return {
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'schema_name': tenant.schema_name,
            'empresa': tenant.name,
        }
