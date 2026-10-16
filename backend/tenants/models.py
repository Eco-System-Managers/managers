import uuid
from django.db import models
from django.contrib.auth.models import User
from django_tenants.models import TenantMixin, DomainMixin


class Tenant(TenantMixin):
    name = models.CharField(max_length=255)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    auto_create_schema = True

    def __str__(self):
        return self.name


class Domain(DomainMixin):
    pass


class UserTenant(models.Model):
    ROLE_CHOICES = [
        ('proprietario', 'Proprietário'),
        ('colaborador', 'Colaborador'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='tenants')
    tenant = models.ForeignKey(Tenant, on_delete=models.CASCADE, related_name='membros')
    role = models.CharField(max_length=20, choices=ROLE_CHOICES)

    class Meta:
        unique_together = ['user', 'tenant']

    def __str__(self):
        return f'{self.user.email} → {self.tenant.name} ({self.role})'


class ConviteIndex(models.Model):
    """Índice público que mapeia token de convite → schema do tenant. Nunca exposto ao cliente."""
    token = models.UUIDField(unique=True, db_index=True, default=uuid.uuid4)
    schema_name = models.CharField(max_length=63)
    criado_em = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.token} → {self.schema_name}'
