from django.contrib import admin, messages

from .models import Assinatura, PagamentoAssinatura, Plano
from .services import AssinaturaInvalidaError, conceder_acesso_vitalicio, revogar_acesso_vitalicio


@admin.register(Plano)
class PlanoAdmin(admin.ModelAdmin):
    list_display = ['nome', 'preco_mensal', 'ativo', 'id_externo']
    # O preço também está gravado no plano do Mercado Pago. Mudar só aqui
    # deixaria os dois divergindo: quem muda é `manage.py configurar_plano`,
    # que acerta os dois juntos — e é ele que cria o plano.
    readonly_fields = ['preco_mensal', 'gateway', 'id_externo', 'link_checkout']

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


class PagamentoInline(admin.TabularInline):
    model = PagamentoAssinatura
    fields = ['data', 'valor', 'status', 'id_externo']
    readonly_fields = fields
    extra = 0
    can_delete = False
    ordering = ['-data']

    def has_add_permission(self, request, obj=None):
        return False


@admin.register(Assinatura)
class AssinaturaAdmin(admin.ModelAdmin):
    list_display = ['tenant', 'plano', 'status', 'proximo_vencimento', 'trial_fim', 'vitalicia', 'bloqueada']
    list_filter = ['status', 'plano']
    search_fields = ['tenant__nome', 'tenant__schema_name']
    list_select_related = ['tenant', 'plano']
    # O vínculo com o gateway só muda pelo fluxo de cobrança: editado à mão,
    # o webhook deixaria de achar a assinatura (ou acharia a errada).
    readonly_fields = ['tenant', 'gateway', 'id_externo']
    inlines = [PagamentoInline]
    actions = ['conceder_vitalicio', 'revogar_vitalicio']

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False

    @admin.display(boolean=True, description='Vitalícia')
    def vitalicia(self, obj):
        return obj.vitalicia

    @admin.display(boolean=True, description='Bloqueada')
    def bloqueada(self, obj):
        return obj.bloqueada

    @admin.action(description='Conceder acesso vitalício')
    def conceder_vitalicio(self, request, queryset):
        self._aplicar(request, queryset, conceder_acesso_vitalicio, 'Acesso vitalício concedido')

    @admin.action(description='Revogar acesso vitalício')
    def revogar_vitalicio(self, request, queryset):
        self._aplicar(request, queryset, revogar_acesso_vitalicio, 'Acesso vitalício revogado')

    def _aplicar(self, request, queryset, operacao, sucesso):
        # Um por um, e não queryset.update(): o save() da Assinatura limpa o
        # cache do bloqueio, e o update() pularia isso.
        for assinatura in queryset.select_related('tenant'):
            try:
                operacao(assinatura)
            except AssinaturaInvalidaError as e:
                self.message_user(request, f'{assinatura.tenant}: {e}', messages.ERROR)
            else:
                self.message_user(request, f'{sucesso}: {assinatura.tenant}.', messages.SUCCESS)


@admin.register(PagamentoAssinatura)
class PagamentoAssinaturaAdmin(admin.ModelAdmin):
    list_display = ['assinatura', 'data', 'valor', 'status']
    list_filter = ['status']
    search_fields = ['assinatura__tenant__nome', 'id_externo']
    list_select_related = ['assinatura__tenant']
    ordering = ['-data']

    # Histórico do que o gateway informou: só leitura.
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
