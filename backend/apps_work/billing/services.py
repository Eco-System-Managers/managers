import hashlib
import hmac
from datetime import date, timedelta
from decimal import Decimal

import mercadopago
import requests
from django.conf import settings

from .models import Assinatura, Pagamento, Plano


class AssinaturaInvalidaError(Exception):
    pass


class WebhookInvalidoError(Exception):
    pass


class PreapprovalInvalidoError(Exception):
    pass


class MercadoPagoService:
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
            'back_url': f'{settings.MERCADOPAGO_BACK_URL}/api/billing/retorno/',
        })
        if resultado['status'] not in (200, 201):
            raise AssinaturaInvalidaError(f'Erro ao criar plano no Mercado Pago: {resultado["response"]}')

        resposta = resultado['response']
        plano.mercadopago_plan_id = resposta['id']
        plano.mercadopago_init_point = resposta.get('init_point', '')
        plano.save(update_fields=['mercadopago_plan_id', 'mercadopago_init_point'])
        return plano.mercadopago_plan_id

    def obter_link_assinatura(self, plano: Plano) -> str:
        """Devolve o link de checkout hospedado pelo Mercado Pago pro plano.
        Não criamos a assinatura pela API (isso exigiria capturar o cartão no
        nosso frontend) — o proprietário completa tudo direto no Mercado
        Pago, e a gente descobre que ele assinou via webhook."""
        if not plano.mercadopago_init_point:
            raise AssinaturaInvalidaError('Este plano ainda não foi criado no Mercado Pago.')
        return plano.mercadopago_init_point

    def confirmar_assinatura(self, tenant, preapproval_id: str) -> Assinatura:
        """Chamado quando o proprietário volta do checkout do Mercado Pago já
        autenticado no nosso sistema — usamos a sessão dele pra saber a qual
        tenant vincular a assinatura, em vez de depender do e-mail do pagador
        (que a API do Mercado Pago não vem preenchendo de forma confiável)."""
        resultado = self._sdk.preapproval().get(preapproval_id)
        if resultado['status'] != 200:
            raise PreapprovalInvalidoError('Não foi possível confirmar a assinatura no Mercado Pago.')

        resposta = resultado['response']
        if resposta.get('status') != 'authorized':
            raise PreapprovalInvalidoError('Esta assinatura ainda não foi autorizada no Mercado Pago.')

        ja_vinculada_a_outro = Assinatura.objects.filter(
            mercadopago_preapproval_id=preapproval_id,
        ).exclude(tenant=tenant).exists()
        if ja_vinculada_a_outro:
            raise PreapprovalInvalidoError('Esta assinatura já está vinculada a outro negócio.')

        try:
            assinatura = Assinatura.objects.get(tenant=tenant)
        except Assinatura.DoesNotExist:
            raise PreapprovalInvalidoError('Este negócio ainda não tem assinatura configurada.')

        assinatura.mercadopago_preapproval_id = preapproval_id
        assinatura.status = 'ativa'
        assinatura.proximo_vencimento = date.today() + timedelta(days=30)
        assinatura.save(update_fields=['mercadopago_preapproval_id', 'status', 'proximo_vencimento'])
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
            raise PreapprovalInvalidoError('Este negócio ainda não tem assinatura.')

        if assinatura.status != 'ativa' or not assinatura.mercadopago_preapproval_id:
            raise PreapprovalInvalidoError('Não há assinatura ativa para cancelar.')

        resultado = self._sdk.preapproval().update(assinatura.mercadopago_preapproval_id, {'status': 'cancelled'})
        if resultado['status'] != 200:
            raise PreapprovalInvalidoError('Não foi possível cancelar a assinatura no Mercado Pago. Tente novamente.')

        assinatura.status = 'cancelada'
        assinatura.save(update_fields=['status'])
        return assinatura

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
        if not ts or not v1:
            return False

        manifest = f'id:{data_id};request-id:{x_request_id or ""};ts:{ts};'
        assinatura_calculada = hmac.new(
            settings.MERCADOPAGO_WEBHOOK_SECRET.encode(),
            manifest.encode(),
            hashlib.sha256,
        ).hexdigest()

        return hmac.compare_digest(assinatura_calculada, v1)

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
        from tenants.models import UserTenant

        vinculo = UserTenant.objects.filter(
            user__email__iexact=email, role='proprietario',
        ).select_related('tenant').first()
        if vinculo is None:
            return None
        return Assinatura.objects.filter(tenant=vinculo.tenant).first()

    def _processar_preapproval(self, preapproval_id: str) -> None:
        resultado = self._sdk.preapproval().get(preapproval_id)
        if resultado['status'] != 200:
            return
        resposta = resultado['response']

        assinatura = Assinatura.objects.filter(mercadopago_preapproval_id=preapproval_id).first()
        if assinatura is None:
            assinatura = self._buscar_assinatura_por_email(resposta.get('payer_email'))
            if assinatura is None:
                return
            assinatura.mercadopago_preapproval_id = preapproval_id

        status_map = {'authorized': 'ativa', 'paused': 'inadimplente', 'cancelled': 'cancelada'}
        novo_status = status_map.get(resposta.get('status'))
        if novo_status:
            assinatura.status = novo_status
        assinatura.save()

    def _processar_pagamento(self, payment_id: str) -> None:
        if Pagamento.objects.filter(mercadopago_payment_id=payment_id).exists():
            return  # já processado — idempotência

        resultado = self._sdk.payment().get(payment_id)
        if resultado['status'] != 200:
            return
        resposta = resultado['response']

        assinatura = None
        preapproval_id = resposta.get('metadata', {}).get('preapproval_id')
        if preapproval_id:
            assinatura = Assinatura.objects.filter(mercadopago_preapproval_id=preapproval_id).first()
        if assinatura is None:
            assinatura = self._buscar_assinatura_por_email(resposta.get('payer', {}).get('email'))
        if assinatura is None:
            return

        status_map = {'approved': 'pago', 'pending': 'pendente', 'rejected': 'falhou'}
        Pagamento.objects.create(
            assinatura=assinatura,
            valor=Decimal(str(resposta.get('transaction_amount', 0))),
            status=status_map.get(resposta.get('status'), 'pendente'),
            data=date.today(),
            mercadopago_payment_id=payment_id,
        )

        if resposta.get('status') == 'approved':
            assinatura.status = 'ativa'
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
        if Pagamento.objects.filter(mercadopago_payment_id=str(authorized_payment_id)).exists():
            return  # já processado — idempotência

        resposta = self._buscar_authorized_payment(authorized_payment_id)
        if resposta is None:
            return

        preapproval_id = resposta.get('preapproval_id')
        assinatura = Assinatura.objects.filter(mercadopago_preapproval_id=preapproval_id).first() if preapproval_id else None
        if assinatura is None:
            return

        status_pagamento = resposta.get('payment', {}).get('status')
        status_map = {'approved': 'pago', 'pending': 'pendente', 'rejected': 'falhou'}
        Pagamento.objects.create(
            assinatura=assinatura,
            valor=Decimal(str(resposta.get('transaction_amount', 0))),
            status=status_map.get(status_pagamento, 'pendente'),
            data=date.today(),
            mercadopago_payment_id=str(authorized_payment_id),
        )

        if status_pagamento == 'approved':
            assinatura.status = 'ativa'
            assinatura.proximo_vencimento = date.today() + timedelta(days=30)
            assinatura.save(update_fields=['status', 'proximo_vencimento'])
