import hashlib
import hmac
import time
from datetime import date, timedelta
from decimal import Decimal

import mercadopago
import requests
from django.conf import settings
from django.urls import reverse

from .models import (
    VENCIMENTO_VITALICIO, Assinatura, Gateway, PagamentoAssinatura, Plano, StatusAssinatura, StatusPagamento, TipoPlano,
)
from tenants.models import Papel


class AssinaturaInvalidaError(Exception):
    pass


class WebhookInvalidoError(Exception):
    pass


class AssinaturaGatewayError(Exception):
    """O gateway recusou ou não confirmou a operação na assinatura."""


class GatewayPagamento:
    """O que o billing precisa de um provedor de pagamento.

    Cobrança da plataforma ao negócio (não o pagamento de atendimento). Hoje só
    há o Mercado Pago; outro provedor implementa estes métodos e entra em
    `GATEWAYS`. O webhook é específico de cada provedor e fica fora daqui.
    """

    codigo = None

    def criar_plano_no_gateway(self, plano: Plano) -> str:
        raise NotImplementedError

    def obter_link_assinatura(self, plano: Plano) -> str:
        raise NotImplementedError

    def confirmar_assinatura(self, tenant, id_externo: str) -> Assinatura:
        raise NotImplementedError

    def cancelar_assinatura(self, tenant) -> Assinatura:
        raise NotImplementedError


class MercadoPagoGateway(GatewayPagamento):
    codigo = Gateway.MERCADO_PAGO

    def __init__(self):
        self._sdk = mercadopago.SDK(settings.MERCADOPAGO_ACCESS_TOKEN)

    def criar_plano_no_gateway(self, plano: Plano) -> str:
        """Cria o preapproval_plan no Mercado Pago pra esse Plano e salva o id
        e o link de checkout (init_point) retornados. Só precisa ser chamado
        uma vez por plano (não a cada request)."""
        resultado = self._sdk.plan().create({
            'reason': f'Work Manage — Plano {plano.get_nome_display()}',
            'auto_recurring': {
                'frequency': 1,
                'frequency_type': 'months',
                'transaction_amount': float(plano.preco_mensal),
                'currency_id': 'BRL',
            },
            # Aponta pro nosso próprio backend, não pro site institucional — é
            # esse endpoint que repassa a pessoa de volta pro frontend depois
            # do checkout (ver RetornoCheckoutView).
            'back_url': f"{settings.MERCADOPAGO_BACK_URL}{reverse('retorno-checkout')}",
        })
        if resultado['status'] not in (200, 201):
            raise AssinaturaInvalidaError(f'Erro ao criar plano no Mercado Pago: {resultado["response"]}')

        resposta = resultado['response']
        plano.gateway = self.codigo
        plano.id_externo = resposta['id']
        plano.link_checkout = resposta.get('init_point', '')
        plano.save(update_fields=['gateway', 'id_externo', 'link_checkout'])
        return plano.id_externo

    def obter_link_assinatura(self, plano: Plano) -> str:
        """Devolve o link de checkout hospedado pelo Mercado Pago pro plano.
        Não criamos a assinatura pela API (isso exigiria capturar o cartão no
        nosso frontend) — o proprietário completa tudo direto no Mercado
        Pago, e a gente descobre que ele assinou via webhook."""
        if not plano.link_checkout:
            raise AssinaturaInvalidaError('Este plano ainda não foi criado no Mercado Pago.')
        return plano.link_checkout

    def confirmar_assinatura(self, tenant, id_externo: str) -> Assinatura:
        """Chamado quando o proprietário volta do checkout do Mercado Pago já
        autenticado no nosso sistema — usamos a sessão dele pra saber a qual
        tenant vincular a assinatura, em vez de depender do e-mail do pagador
        (que a API do Mercado Pago não vem preenchendo de forma confiável)."""
        resultado = self._sdk.preapproval().get(id_externo)
        if resultado['status'] != 200:
            raise AssinaturaGatewayError('Não foi possível confirmar a assinatura no Mercado Pago.')

        resposta = resultado['response']
        if resposta.get('status') != 'authorized':
            raise AssinaturaGatewayError('Esta assinatura ainda não foi autorizada no Mercado Pago.')

        ja_vinculada_a_outro = self._assinaturas(id_externo).exclude(tenant=tenant).exists()
        if ja_vinculada_a_outro:
            raise AssinaturaGatewayError('Esta assinatura já está vinculada a outro negócio.')

        try:
            assinatura = Assinatura.objects.get(tenant=tenant)
        except Assinatura.DoesNotExist:
            raise AssinaturaGatewayError('Este negócio ainda não tem assinatura configurada.')

        assinatura.gateway = self.codigo
        assinatura.id_externo = id_externo
        assinatura.status = StatusAssinatura.ATIVA
        assinatura.proximo_vencimento = date.today() + timedelta(days=30)
        assinatura.save(update_fields=['gateway', 'id_externo', 'status', 'proximo_vencimento'])
        return assinatura

    def cancelar_assinatura(self, tenant) -> Assinatura:
        """Cancela no Mercado Pago primeiro (garante que as cobranças futuras
        realmente param) e só então atualiza localmente — evita um estado
        onde achamos que cancelamos mas o Mercado Pago continua cobrando.
        Não bloqueia o acesso na hora: quem chama isso decide, via
        Assinatura.bloqueada, que o acesso continua até proximo_vencimento."""
        try:
            assinatura = Assinatura.objects.get(tenant=tenant)
        except Assinatura.DoesNotExist:
            raise AssinaturaGatewayError('Este negócio ainda não tem assinatura.')

        if assinatura.status != StatusAssinatura.ATIVA or not assinatura.id_externo:
            raise AssinaturaGatewayError('Não há assinatura ativa para cancelar.')

        resultado = self._sdk.preapproval().update(assinatura.id_externo, {'status': 'cancelled'})
        if resultado['status'] != 200:
            raise AssinaturaGatewayError('Não foi possível cancelar a assinatura no Mercado Pago. Tente novamente.')

        assinatura.status = StatusAssinatura.CANCELADA
        assinatura.save(update_fields=['status'])
        return assinatura

    def _assinaturas(self, id_externo: str):
        return Assinatura.objects.filter(gateway=self.codigo, id_externo=id_externo)

    def _pagamento_ja_registrado(self, id_externo: str) -> bool:
        return PagamentoAssinatura.objects.filter(gateway=self.codigo, id_externo=id_externo).exists()

    def _validar_assinatura_webhook(self, x_signature: str, x_request_id: str, data_id: str) -> bool:
        """Valida o header x-signature (formato 'ts=...,v1=...') seguindo o
        algoritmo documentado pelo Mercado Pago: HMAC-SHA256 do manifest
        'id:{data_id};request-id:{x_request_id};ts:{ts};' usando o webhook
        secret como chave."""
        if not x_signature or not settings.MERCADOPAGO_WEBHOOK_SECRET:
            return False

        partes = dict(p.split('=', 1) for p in x_signature.split(',') if '=' in p)
        ts = partes.get('ts')
        v1 = partes.get('v1')
        if not ts or not v1 or not self._ts_recente(ts):
            return False

        manifest = f'id:{data_id};request-id:{x_request_id or ""};ts:{ts};'
        assinatura_calculada = hmac.new(
            settings.MERCADOPAGO_WEBHOOK_SECRET.encode(),
            manifest.encode(),
            hashlib.sha256,
        ).hexdigest()

        return hmac.compare_digest(assinatura_calculada, v1)

    # Notificação assinada há mais tempo que isso é recusada: sem a janela, uma
    # notificação capturada poderia ser reenviada a qualquer momento.
    TOLERANCIA_WEBHOOK_SEGUNDOS = 10 * 60

    def _ts_recente(self, ts: str) -> bool:
        try:
            instante = int(ts)
        except ValueError:
            return False
        # Aceita o ts em segundos ou em milissegundos.
        if instante > 10**12:
            instante //= 1000
        return abs(time.time() - instante) <= self.TOLERANCIA_WEBHOOK_SEGUNDOS

    def processar_webhook(self, topico: str, data_id: str, x_signature: str, x_request_id: str) -> None:
        """Processa uma notificação do Mercado Pago. Levanta WebhookInvalidoError
        se a assinatura HMAC não bater — nunca confiar no payload sem validar."""
        if not self._validar_assinatura_webhook(x_signature, x_request_id, data_id):
            raise WebhookInvalidoError('Assinatura do webhook inválida.')

        if topico == 'subscription_preapproval':
            self._processar_preapproval(data_id)
        elif topico == 'subscription_authorized_payment':
            self._processar_pagamento_autorizado(data_id)
        elif topico == 'payment':
            self._processar_pagamento(data_id)
        # outros tópicos são ignorados silenciosamente — não fazem parte do escopo atual

    def _buscar_assinatura_por_email(self, email: str):
        """Como a assinatura é criada pelo próprio Mercado Pago (checkout
        hospedado, sem card_token no nosso lado), não temos um
        external_reference definido por nós — a correlação com o tenant é
        feita pelo e-mail do proprietário (único no sistema, é o mesmo
        e-mail de login)."""
        if not email:
            return None
        from tenants.models import Membro

        vinculo = Membro.objects.filter(
            user__email__iexact=email, papel=Papel.PROPRIETARIO,
        ).select_related('tenant').first()
        if vinculo is None:
            return None
        return Assinatura.objects.filter(tenant=vinculo.tenant).first()

    def _processar_preapproval(self, preapproval_id: str) -> None:
        resultado = self._sdk.preapproval().get(preapproval_id)
        if resultado['status'] != 200:
            return
        resposta = resultado['response']

        assinatura = self._assinaturas(preapproval_id).first()
        if assinatura is None:
            assinatura = self._buscar_assinatura_por_email(resposta.get('payer_email'))
            if assinatura is None:
                return
            assinatura.gateway = self.codigo
            assinatura.id_externo = preapproval_id

        status_map = {
            'authorized': StatusAssinatura.ATIVA,
            'paused': StatusAssinatura.INADIMPLENTE,
            'cancelled': StatusAssinatura.CANCELADA,
        }
        novo_status = status_map.get(resposta.get('status'))
        if novo_status:
            assinatura.status = novo_status
        assinatura.save()

    def _processar_pagamento(self, payment_id: str) -> None:
        if self._pagamento_ja_registrado(payment_id):
            return  # já processado — idempotência

        resultado = self._sdk.payment().get(payment_id)
        if resultado['status'] != 200:
            return
        resposta = resultado['response']

        assinatura = None
        preapproval_id = resposta.get('metadata', {}).get('preapproval_id')
        if preapproval_id:
            assinatura = self._assinaturas(preapproval_id).first()
        if assinatura is None:
            assinatura = self._buscar_assinatura_por_email(resposta.get('payer', {}).get('email'))
        if assinatura is None:
            return

        status_map = {
            'approved': StatusPagamento.PAGO,
            'pending': StatusPagamento.PENDENTE,
            'rejected': StatusPagamento.FALHOU,
        }
        PagamentoAssinatura.objects.create(
            assinatura=assinatura,
            valor=Decimal(str(resposta.get('transaction_amount', 0))),
            status=status_map.get(resposta.get('status'), StatusPagamento.PENDENTE),
            data=date.today(),
            gateway=self.codigo,
            id_externo=payment_id,
        )

        if resposta.get('status') == 'approved':
            assinatura.status = StatusAssinatura.ATIVA
            assinatura.proximo_vencimento = date.today() + timedelta(days=30)
            assinatura.save(update_fields=['status', 'proximo_vencimento'])

    def _buscar_authorized_payment(self, authorized_payment_id: str) -> dict | None:
        """O recurso 'authorized payment' (cobrança recorrente de uma
        assinatura) não tem wrapper no SDK — é um endpoint diferente do
        pagamento comum (/authorized_payments/{id}, não /v1/payments/{id}).
        Chama a API REST direto."""
        resposta = requests.get(
            f'https://api.mercadopago.com/authorized_payments/{authorized_payment_id}',
            headers={'Authorization': f'Bearer {settings.MERCADOPAGO_ACCESS_TOKEN}'},
            timeout=10,
        )
        if resposta.status_code != 200:
            return None
        return resposta.json()

    def _processar_pagamento_autorizado(self, authorized_payment_id: str) -> None:
        """Cobrança recorrente de uma assinatura já existente. Diferente de
        _processar_pagamento: aqui a correlação é direta via preapproval_id
        (não precisa de e-mail), porque o authorized_payment já vem
        vinculado à assinatura que o gerou."""
        if self._pagamento_ja_registrado(str(authorized_payment_id)):
            return  # já processado — idempotência

        resposta = self._buscar_authorized_payment(authorized_payment_id)
        if resposta is None:
            return

        preapproval_id = resposta.get('preapproval_id')
        assinatura = self._assinaturas(preapproval_id).first() if preapproval_id else None
        if assinatura is None:
            return

        status_pagamento = resposta.get('payment', {}).get('status')
        status_map = {
            'approved': StatusPagamento.PAGO,
            'pending': StatusPagamento.PENDENTE,
            'rejected': StatusPagamento.FALHOU,
        }
        PagamentoAssinatura.objects.create(
            assinatura=assinatura,
            valor=Decimal(str(resposta.get('transaction_amount', 0))),
            status=status_map.get(status_pagamento, StatusPagamento.PENDENTE),
            data=date.today(),
            gateway=self.codigo,
            id_externo=str(authorized_payment_id),
        )

        if status_pagamento == 'approved':
            assinatura.status = StatusAssinatura.ATIVA
            assinatura.proximo_vencimento = date.today() + timedelta(days=30)
            assinatura.save(update_fields=['status', 'proximo_vencimento'])


GATEWAYS = {
    Gateway.MERCADO_PAGO: MercadoPagoGateway,
}


def gateway_de_pagamento() -> GatewayPagamento:
    """O gateway configurado em BILLING_GATEWAY."""
    return GATEWAYS[settings.BILLING_GATEWAY]()



# Preço com que o plano padrão nasce num banco novo. Depois de criado, o preço
# é o que estiver no banco (o admin muda ali).
PRECO_INICIAL_PLANO = {
    TipoPlano.PRO: Decimal('69.90'),
    TipoPlano.BUSINESS: Decimal('99.90'),
    TipoPlano.ENTERPRISE: Decimal('199.90'),
}


def conceder_acesso_vitalicio(assinatura: Assinatura) -> None:
    """Libera o negócio para sempre, sem cobrança.

    Usa o que o bloqueio já entende — `ativa` nunca bloqueia —, então nem o
    middleware nem o app precisam conhecer um status novo. Sem `id_externo`,
    nenhuma notificação do gateway acha a assinatura pelo id.
    """
    if assinatura.status == StatusAssinatura.ATIVA and assinatura.id_externo:
        # Zerar o id aqui deixaria a recorrência viva no gateway, cobrando
        # alguém que já não teria como cancelar pelo app.
        raise AssinaturaInvalidaError(
            'Este negócio paga uma assinatura recorrente. Cancele-a antes, senão a cobrança continua.'
        )
    assinatura.status = StatusAssinatura.ATIVA
    assinatura.id_externo = None
    assinatura.trial_fim = None
    assinatura.proximo_vencimento = VENCIMENTO_VITALICIO
    assinatura.save(update_fields=['status', 'id_externo', 'trial_fim', 'proximo_vencimento'])


def revogar_acesso_vitalicio(assinatura: Assinatura) -> None:
    """Desfaz a concessão: o acesso vale até o fim do dia e depois bloqueia,
    como uma assinatura cancelada que venceu. Para voltar, o negócio assina."""
    if not assinatura.vitalicia:
        raise AssinaturaInvalidaError('Este negócio não tem acesso vitalício.')
    assinatura.status = StatusAssinatura.CANCELADA
    assinatura.proximo_vencimento = date.today()
    assinatura.save(update_fields=['status', 'proximo_vencimento'])


def plano_padrao() -> Plano:
    """O plano de PLANO_PADRAO, criado na primeira vez que alguém precisa dele.

    Sem isso, um banco recém-criado aceitava o cadastro, mas a empresa nascia
    sem assinatura de trial e toda a API respondia 402.
    """
    plano, _ = Plano.objects.get_or_create(
        nome=settings.PLANO_PADRAO,
        defaults={'preco_mensal': PRECO_INICIAL_PLANO[settings.PLANO_PADRAO], 'ativo': True},
    )
    return plano
