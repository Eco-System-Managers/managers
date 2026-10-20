import uuid
from django.db import models
from django.contrib.auth.models import User
from django_tenants.models import TenantMixin, DomainMixin


class Tenant(TenantMixin):
    nome = models.CharField(max_length=255)

    auto_create_schema = True

    def __str__(self):
        return self.nome


class Domain(DomainMixin):
    pass


class Papel(models.TextChoices):
    """Papel do usuário no negócio. A fonte única é o Membro.papel."""
    PROPRIETARIO = 'proprietario', 'Proprietário'
    COLABORADOR = 'colaborador', 'Colaborador'


class Membro(models.Model):
    """Quem pertence a qual negócio, e com que papel.

    Vive no schema público: a autenticação precisa dele antes de saber em que
    tenant entrar. É a fonte única do papel (o Colaborador não tem papel).
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='membros_tenant')
    tenant = models.ForeignKey(Tenant, on_delete=models.CASCADE, related_name='membros')
    papel = models.CharField(max_length=20, choices=Papel.choices)

    class Meta:
        unique_together = ['user', 'tenant']

    def __str__(self):
        return f'{self.user.email} → {self.tenant.nome} ({self.papel})'

    @classmethod
    def papel_subquery(cls, schema_name: str, user_ref: str = 'user_id'):
        """Papel como subquery, para anotar numa consulta de outro schema.

        A tabela do Membro fica no público, que está no search_path de todo
        tenant — então um `.annotate(papel=...)` traz o papel de cada
        colaborador na mesma consulta, sem uma por linha.
        """
        return models.Subquery(
            cls.objects.filter(user_id=models.OuterRef(user_ref), tenant__schema_name=schema_name)
            .values('papel')[:1]
        )

    @classmethod
    def papel_no_schema(cls, user, schema_name: str) -> str | None:
        """Papel do usuário no tenant do schema, ou None se ele não pertence a ele.

        É a fonte única do papel: existe desde o cadastro, antes de o
        `Colaborador` do dono ser criado no fim do onboarding.
        """
        return (
            cls.objects.filter(user_id=user.pk, tenant__schema_name=schema_name)
            .values_list('papel', flat=True)
            .first()
        )


class ConviteIndex(models.Model):
    """Índice público que mapeia token de convite → schema do tenant. Nunca exposto ao cliente."""
    token = models.UUIDField(unique=True, db_index=True, default=uuid.uuid4)
    schema_name = models.CharField(max_length=63)
    criado_em = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.token} → {self.schema_name}'
