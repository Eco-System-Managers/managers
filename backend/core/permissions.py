from rest_framework.permissions import BasePermission

from apps_work.usuarios.models import Colaborador


class IsProprietario(BasePermission):
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        try:
            return request.user.colaborador.role == 'proprietario'
        except Colaborador.DoesNotExist:
            # Sem Colaborador ainda (onboarding) — usuário é o dono da conta.
            #
            # A exceção capturada é a específica de propósito. Enquanto isto era
            # `except Exception`, qualquer falha inesperada na resolução do
            # colaborador (erro de banco, schema errado, request.user que não é
            # User) caía neste mesmo return e concedia permissão de proprietário
            # — uma permissão que falha abrindo a porta em vez de fechando.
            return True
