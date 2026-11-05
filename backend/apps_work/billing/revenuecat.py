"""A assinatura comprada nas lojas (App Store e Google Play), pelo RevenueCat.

Quem cobra é a loja; o RevenueCat confere as compras das duas e avisa. O
backend continua sendo quem decide o acesso: guarda na `Assinatura` o plano e
até quando ele vale, e o bloqueio (`Assinatura.bloqueada`) segue igual.

O negócio é o cliente do RevenueCat: o app entra nele com o `schema_name` do
tenant como `appUserID`, e é por esse id que o webhook acha a assinatura.
Cada plano é um entitlement com o mesmo nome do `TipoPlano` (`pro`,
`business`, `enterprise`), e os produtos das lojas (mensal, semestral e anual)
ficam ligados a ele no painel do RevenueCat.

O estado nunca vem do corpo do webhook: ele só diz quem mudou, e a verdade é
lida na API do RevenueCat (`sincronizar`). Assim o evento repetido, fora de
ordem ou perdido não deixa a assinatura errada, e o app pode pedir a mesma
leitura logo depois da compra, sem esperar o webhook.
"""
import hmac
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal, InvalidOperation
from urllib.parse import quote

import requests
from django.conf import settings
from django.utils import timezone
from django.utils.dateparse import parse_datetime

from .models import (
    VENCIMENTO_VITALICIO, Assinatura, Gateway, PagamentoAssinatura, StatusAssinatura, StatusPagamento, TipoPlano,
)
from .services import WebhookInvalidoError, plano_do_tipo

API = 'https://api.revenuecat.com/v1'

# Do menor para o maior: com dois planos ativos ao mesmo tempo (a troca ainda
# não virou), vale o maior.
ORDEM_DOS_PLANOS = [TipoPlano.PRO, TipoPlano.BUSINESS, TipoPlano.ENTERPRISE]

# Eventos que são uma cobrança: entram no histórico de pagamentos.
EVENTOS_COM_COBRANCA = {'INITIAL_PURCHASE', 'RENEWAL', 'NON_RENEWING_PURCHASE'}


class RevenueCatIndisponivelError(Exception):
    """A API do RevenueCat não respondeu: quem chamou tenta de novo depois."""


def _instante(valor) -> datetime | None:
    """As datas do RevenueCat: ISO na API, milissegundos no webhook."""
    if valor in (None, ''):
        return None
    if isinstance(valor, (int, float)):
        return datetime.fromtimestamp(valor / 1000, tz=UTC)
    return parse_datetime(valor)


def _dia(instante: datetime) -> date:
    return timezone.localtime(instante).date()


class RevenueCat:
    def buscar_assinante(self, app_user_id: str) -> dict:
        try:
            resposta = requests.get(
                f'{API}/subscribers/{quote(app_user_id, safe="")}',
                headers={'Authorization': f'Bearer {settings.REVENUECAT_SECRET_KEY}'},
                timeout=10,
            )
        except requests.RequestException as e:
            raise RevenueCatIndisponivelError(str(e)) from e
        if resposta.status_code != 200:
            raise RevenueCatIndisponivelError(f'RevenueCat respondeu {resposta.status_code}')
        return resposta.json().get('subscriber') or {}

    def sincronizar(self, tenant) -> Assinatura | None:
        """Lê no RevenueCat o que o negócio comprou e acerta a `Assinatura`.

        Sem compra nenhuma, nada muda: o teste grátis segue como está. O
        vitalício também não muda: é concessão nossa, fora das lojas.
        """
        assinatura = Assinatura.objects.select_related('plano').filter(tenant=tenant).first()
        if assinatura is None or assinatura.vitalicia:
            return assinatura

        assinante = self.buscar_assinante(tenant.schema_name)
        agora = timezone.now()

        vigentes = []
        for tipo in ORDEM_DOS_PLANOS:
            direito = (assinante.get('entitlements') or {}).get(tipo)
            if not direito:
                continue
            fim = _instante(direito.get('expires_date'))
            # O período de carência: a loja ainda tenta cobrar o cartão, e o
            # acesso continua enquanto isso.
            carencia = _instante(direito.get('grace_period_expires_date'))
            validade = max((d for d in (fim, carencia) if d), default=None)
            if validade is None or validade > agora:
                vigentes.append((tipo, validade, direito))

        if vigentes:
            tipo, validade, direito = max(vigentes, key=lambda v: ORDEM_DOS_PLANOS.index(v[0]))
            compra = (assinante.get('subscriptions') or {}).get(direito.get('product_identifier'), {})
            if assinatura.status == StatusAssinatura.TRIAL:
                inicio = _instante(direito.get('purchase_date'))
                assinatura.inicio = _dia(inicio) if inicio else date.today()
            assinatura.plano = plano_do_tipo(tipo)
            # Cancelar na loja não corta o acesso: vale até o fim do período
            # pago, que é como `cancelada` já funciona no bloqueio.
            assinatura.status = (
                StatusAssinatura.CANCELADA if compra.get('unsubscribe_detected_at') else StatusAssinatura.ATIVA
            )
            assinatura.proximo_vencimento = _dia(validade) if validade else VENCIMENTO_VITALICIO
        else:
            compras = assinante.get('subscriptions') or {}
            if not compras:
                return assinatura
            fins = [_instante(c.get('expires_date')) for c in compras.values()]
            ultimo_fim = max((f for f in fins if f), default=agora)
            if assinatura.trial_fim and assinatura.trial_fim >= date.today():
                # Comprou durante o teste e a compra acabou antes dele: o
                # resto do teste continua valendo.
                assinatura.status = StatusAssinatura.TRIAL
                assinatura.proximo_vencimento = assinatura.trial_fim
            else:
                assinatura.status = StatusAssinatura.CANCELADA
                assinatura.proximo_vencimento = min(_dia(ultimo_fim), date.today() - timedelta(days=1))

        assinatura.gateway = Gateway.REVENUECAT
        assinatura.id_externo = tenant.schema_name
        # save() inteiro, e não update_fields: é ele que limpa o cache do bloqueio.
        assinatura.save()
        return assinatura

    def processar_webhook(self, corpo: dict, autorizacao: str) -> None:
        """Valida o segredo do webhook e sincroniza os negócios do evento.

        O webhook é público: sem conferir o `Authorization` (o valor que se
        cadastra no painel do RevenueCat), qualquer um faria o backend ler a
        API. Levanta `RevenueCatIndisponivelError` quando a leitura falha,
        para a view responder erro e o RevenueCat reenviar.
        """
        segredo = settings.REVENUECAT_WEBHOOK_AUTH
        if not segredo or not hmac.compare_digest(autorizacao.encode(), segredo.encode()):
            raise WebhookInvalidoError('Autorização do webhook inválida.')

        from tenants.models import Tenant

        evento = corpo.get('event') or {}
        # A transferência (a mesma conta da loja usada em outro negócio) vem
        # sem app_user_id, com os dois lados em transferred_from/to.
        ids = {
            evento.get('app_user_id'), evento.get('original_app_user_id'),
            *(evento.get('aliases') or []), *(evento.get('transferred_from') or []),
            *(evento.get('transferred_to') or []),
        } - {None, '', 'public'}
        for tenant in Tenant.objects.filter(schema_name__in=ids):
            assinatura = self.sincronizar(tenant)
            if assinatura is not None and tenant.schema_name == evento.get('app_user_id'):
                self._registrar_cobranca(assinatura, evento)

    def _registrar_cobranca(self, assinatura: Assinatura, evento: dict) -> None:
        if evento.get('type') not in EVENTOS_COM_COBRANCA or evento.get('period_type') == 'TRIAL':
            return
        transacao = evento.get('transaction_id')
        if not transacao:
            return
        try:
            valor = Decimal(str(evento.get('price_in_purchased_currency') or 0)).quantize(Decimal('0.01'))
        except InvalidOperation:
            valor = Decimal('0.00')
        comprado_em = _instante(evento.get('purchased_at_ms'))
        # O id da transação com o gateway é único: o evento reenviado não
        # duplica a cobrança.
        PagamentoAssinatura.objects.get_or_create(
            gateway=Gateway.REVENUECAT,
            id_externo=str(transacao),
            defaults={
                'assinatura': assinatura,
                'valor': valor,
                'status': StatusPagamento.PAGO,
                'data': _dia(comprado_em) if comprado_em else date.today(),
            },
        )
