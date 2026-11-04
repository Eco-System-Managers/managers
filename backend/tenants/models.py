import uuid
from django.db import models
from django.contrib.auth.models import User


class Tenant(models.Model):
    """Um negócio. Todas as tabelas de negócio apontam para cá (`tenant_id`);
    quem filtra por ele é o `core.tenant.TenantManager` e as políticas de RLS.

    `schema_name` é o slug do negócio. O nome vem da época em que cada
    negócio tinha um schema no Postgres; continua por ser o identificador
    que o JWT, os links e o app do cliente carregam.
    """
    schema_name = models.CharField(max_length=63, unique=True, db_index=True)
    nome = models.CharField(max_length=255)

    def __str__(self):
        return self.nome


class Domain(models.Model):
    """O subdomínio de um negócio (`<slug>.<TENANT_DOMAIN_SUFFIX>`)."""
    domain = models.CharField(max_length=253, unique=True, db_index=True)
    tenant = models.ForeignKey(Tenant, on_delete=models.CASCADE, related_name='domains')
    is_primary = models.BooleanField(default=True, db_index=True)

    def __str__(self):
        return self.domain


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

        Um `.annotate(papel=...)` traz o papel de cada colaborador na mesma
        consulta, sem uma por linha.
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
    """Índice que mapeia token de convite → slug do tenant. Nunca exposto ao cliente."""
    token = models.UUIDField(unique=True, db_index=True, default=uuid.uuid4)
    schema_name = models.CharField(max_length=63)
    criado_em = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.token} → {self.schema_name}'
