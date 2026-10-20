from django.db import connection
from rest_framework.permissions import BasePermission

from tenants.models import Papel, UserTenant


class IsProprietario(BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        # O papel vem do UserTenant, a fonte única. A TenantJWTAuthentication já
        # o deixa no usuário; a consulta cobre quem chega por outro caminho.
        #
        # Sem vínculo com o tenant atual, nega. Antes, usuário sem Colaborador
        # era tratado como dono (onboarding) — e isso valia também para quem
        # nem pertencia ao tenant.
        if hasattr(request.user, 'papel_no_tenant'):
            papel = request.user.papel_no_tenant
        else:
            papel = UserTenant.papel_no_schema(request.user, connection.schema_name)
        return papel == Papel.PROPRIETARIO
