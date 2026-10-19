from django.db import connection
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.authentication import JWTAuthentication

from tenants.models import UserTenant


class TenantJWTAuthentication(JWTAuthentication):
    """JWT do B2B válido apenas no tenant a que o usuário pertence.

    A checagem fica na autenticação, e não numa permissão padrão, porque quase
    toda view do B2B declara as próprias `permission_classes` — e com isso
    ignoraria qualquer `DEFAULT_PERMISSION_CLASSES`. Já a autenticação nenhuma
    view autenticada sobrescreve.

    Duas condições, porque o schema ativo pode vir de dois lugares:

    - pelo Host (TenantMainMiddleware), o token pode ser de outro tenant —
      daí a comparação com o `schema_name` do token
    - pelo token (JWTTenantMiddleware), o schema é o do token, mas o vínculo
      pode ter deixado de existir — daí a consulta ao `UserTenant`

    O papel encontrado fica em `user.papel_no_tenant`, para o `IsProprietario`
    não consultar de novo.
    """

    def get_user(self, validated_token):
        user = super().get_user(validated_token)

        schema_name = connection.schema_name
        if schema_name == 'public' or validated_token.get('schema_name') != schema_name:
            raise AuthenticationFailed('Token não pertence a esta empresa.', code='tenant_invalido')

        papel = UserTenant.papel_no_schema(user, schema_name)
        if papel is None:
            raise AuthenticationFailed('Usuário não vinculado a esta empresa.', code='tenant_invalido')

        user.papel_no_tenant = papel
        return user
