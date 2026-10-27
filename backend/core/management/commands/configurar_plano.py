from decimal import Decimal, InvalidOperation

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.urls import reverse


class Command(BaseCommand):
    help = (
        'Define a mensalidade do plano e cria no Mercado Pago o plano de assinatura com '
        'esse valor. Rodar de novo com outro preço vale para quem assinar dali em diante: '
        'quem já assina continua no valor antigo.'
    )

    def add_arguments(self, parser):
        from apps_work.billing.models import TipoPlano

        parser.add_argument('--preco', required=True, help='Mensalidade em reais, ex.: 69.90')
        parser.add_argument('--plano', default=None, choices=TipoPlano.values, help='Padrão: PLANO_PADRAO')

    def handle(self, *args, preco, plano, **options):
        from apps_work.billing.models import Plano
        from apps_work.billing.services import AssinaturaInvalidaError, gateway_de_pagamento

        try:
            valor = Decimal(preco.replace(',', '.')).quantize(Decimal('0.01'))
        except InvalidOperation:
            raise CommandError(f'Preço inválido: {preco}. Use, por exemplo, 69.90.')
        if valor <= 0:
            raise CommandError('O preço precisa ser maior que zero.')
        if not settings.MERCADOPAGO_ACCESS_TOKEN:
            raise CommandError('Defina MERCADOPAGO_ACCESS_TOKEN.')
        if not settings.MERCADOPAGO_BACK_URL.startswith('https://'):
            # O Mercado Pago recusa back_url sem https.
            raise CommandError('MERCADOPAGO_BACK_URL precisa começar com https:// (o domínio da API).')

        nome = plano or settings.PLANO_PADRAO
        plano, _ = Plano.objects.get_or_create(nome=nome, defaults={'preco_mensal': valor, 'ativo': True})
        anterior = plano.preco_mensal

        # O preço só é gravado depois que o Mercado Pago aceita: se ele recusar,
        # o banco continua com o valor do plano que o checkout de fato cobra.
        # O plano anterior fica como está lá — as assinaturas feitas nele
        # continuam cobrando o valor dele.
        plano.preco_mensal = valor
        try:
            gateway_de_pagamento().criar_plano_no_gateway(plano)
        except AssinaturaInvalidaError as e:
            raise CommandError(str(e))
        plano.save(update_fields=['preco_mensal'])

        self.stdout.write(self.style.SUCCESS(f'Plano {plano}: R$ {valor}/mês (antes: R$ {anterior}).'))
        self.stdout.write(f'Id no Mercado Pago: {plano.id_externo}')
        self.stdout.write(f'Checkout: {plano.link_checkout}')
        self.stdout.write(f"Retorno do checkout: {settings.MERCADOPAGO_BACK_URL}{reverse('retorno-checkout')}")
