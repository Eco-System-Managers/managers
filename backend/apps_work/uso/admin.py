from django.contrib import admin
from django.contrib.auth.models import User
from django.db.models import OuterRef, Subquery

from tenants.models import Tenant

from .models import EventoDeUso


class ResultadoFilter(admin.SimpleListFilter):
    title = 'resultado'
    parameter_name = 'resultado'

    def lookups(self, request, model_admin):
        return [
            ('sucesso', 'Sucesso'),
            ('regra', 'Erro de regra ou validação (4xx)'),
            ('servidor', 'Erro do servidor (5xx)'),
        ]

    def queryset(self, request, queryset):
        if self.value() == 'sucesso':
            return queryset.filter(status__lt=400)
        if self.value() == 'regra':
            return queryset.filter(status__gte=400, status__lt=500)
        if self.value() == 'servidor':
            return queryset.filter(status__gte=500)
        return queryset


@admin.register(EventoDeUso)
class EventoDeUsoAdmin(admin.ModelAdmin):
    list_display = [
        'criado_em', 'empresa', 'email', 'papel', 'evento', 'objeto_id',
        'status', 'codigo', 'duracao_ms', 'plataforma',
    ]
    list_filter = [ResultadoFilter, 'papel', 'plataforma', 'metodo', 'schema_name']
    search_fields = ['schema_name', 'evento', 'codigo']
    date_hierarchy = 'criado_em'
    list_per_page = 100

    def get_queryset(self, request):
        # O negócio e a pessoa ficam sem FK no evento; a subquery traz os dois
        # na mesma consulta, sem uma por linha.
        return super().get_queryset(request).annotate(
            _empresa=Subquery(Tenant.objects.filter(schema_name=OuterRef('schema_name')).values('nome')[:1]),
            _email=Subquery(User.objects.filter(pk=OuterRef('user_id')).values('email')[:1]),
        )

    @admin.display(description='Empresa', ordering='schema_name')
    def empresa(self, obj):
        return obj._empresa or obj.schema_name or '—'

    @admin.display(description='Usuário')
    def email(self, obj):
        return obj._email or (f'#{obj.user_id}' if obj.user_id else '—')

    # Registro do que aconteceu: só leitura. Apagar fica, para limpar testes.
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
