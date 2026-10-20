"""Bugs encontrados no inventário da reestruturação (issue #5)."""
from decimal import Decimal
from unittest.mock import patch

import pytest
from django.db import IntegrityError, connection
from django.utils import timezone
from rest_framework.test import APIClient

from apps_work.agenda.models import Agendamento, Pagamento
from apps_work.clientes.models import Cliente
from apps_work.servicos.models import Servico


@pytest.fixture
def api(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def cliente(patch_tenant_middleware):
    return Cliente.objects.create(nome='Ana', telefone='11999990000', email='ana@x.com')


@pytest.mark.django_db
class TestFaturamentoDoDashboard:
    def test_pagamento_provisorio_nao_conta_como_receita(self, api, cliente):
        # O que a vitrine cria ao agendar pelo app: agendamento em aberto com
        # pagamento "qr_code" provisório.
        pendente = Agendamento.objects.create(cliente=cliente, data_hora=timezone.now(), status='agendado')
        Pagamento.objects.create(agendamento=pendente, forma='qr_code', valor=Decimal('80.00'))

        concluido = Agendamento.objects.create(cliente=cliente, data_hora=timezone.now(), status='concluido')
        Pagamento.objects.create(agendamento=concluido, forma='pix', valor=Decimal('50.00'))

        kpis = api.get('/api/v1/dashboard/resumo/').json()['kpis']
        assert kpis['faturamento_mes'] == '50.00'

    def test_dashboard_e_caixa_concordam(self, api, cliente):
        cancelado = Agendamento.objects.create(cliente=cliente, data_hora=timezone.now(), status='cancelado')
        Pagamento.objects.create(agendamento=cancelado, forma='pix', valor=Decimal('30.00'))
        concluido = Agendamento.objects.create(cliente=cliente, data_hora=timezone.now(), status='concluido')
        Pagamento.objects.create(agendamento=concluido, forma='pix', valor=Decimal('70.00'))

        hoje = timezone.localdate().isoformat()
        caixa = api.get(f'/api/v1/financeiro/caixa/?data_inicio={hoje}&data_fim={hoje}').json()
        dashboard = api.get('/api/v1/dashboard/resumo/').json()
        assert dashboard['kpis']['faturamento_mes'] == caixa['kpis']['total'] == '70.00'


@pytest.mark.django_db
class TestCobrancaComEntradaInvalida:
    @pytest.fixture
    def agendamento(self, cliente):
        servico = Servico.objects.create(nome='Corte', duracao=30, preco='50.00')
        ag = Agendamento.objects.create(cliente=cliente, data_hora=timezone.now())
        ag.servicos.create(servico=servico, preco_cobrado=servico.preco)
        return ag

    def test_valor_invalido_retorna_400_e_nao_500(self, api, agendamento):
        resposta = api.post(
            f'/api/v1/agendamentos/{agendamento.id}/cobrar/',
            {'desconto': 'abc', 'pagamentos': [{'forma': 'pix', 'valor': '50.00'}]},
            format='json',
        )
        assert resposta.status_code == 400
        assert 'desconto' in resposta.json()['fields']

    def test_forma_de_pagamento_invalida_retorna_400(self, api, agendamento):
        resposta = api.post(
            f'/api/v1/agendamentos/{agendamento.id}/cobrar/',
            {'pagamentos': [{'forma': 'cheque', 'valor': '50.00'}]},
            format='json',
        )
        assert resposta.status_code == 400

    def test_sem_pagamentos_mantem_o_codigo(self, api, agendamento):
        resposta = api.post(f'/api/v1/agendamentos/{agendamento.id}/cobrar/', {'pagamentos': []}, format='json')
        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'sem_pagamentos'


@pytest.mark.django_db
def test_falha_ao_ligar_cliente_nao_aborta_a_transacao(patch_tenant_middleware):
    """Corrida real: outro Cliente já ficou com o consumidor_id. Sem savepoint,
    o IntegrityError deixava a transação do agendamento abortada e a próxima
    consulta falhava ("current transaction is aborted")."""
    from apps_serv.consumidores.services import RegistroConsumidorService
    from apps_serv.identidade import cliente_do_consumidor

    connection.set_schema_to_public()
    consumidor = RegistroConsumidorService().registrar(
        nome='Carla', email='carla@sm.com', senha='SenhaForte123!', telefone='11999990000',
    )
    connection.set_tenant(patch_tenant_middleware)
    Cliente.objects.create(nome='Outra', telefone='11988887777', consumidor_id=consumidor.id)
    por_email = Cliente.objects.create(nome='Carla', telefone='11999990000', email='carla@sm.com')

    # Simula a corrida: a busca por consumidor_id não enxerga o cliente que já
    # tem o id, e a gravação bate na constraint de unicidade de verdade.
    filtro_real = Cliente.objects.filter

    def filtro(*args, **kwargs):
        if kwargs.get('consumidor_id') == consumidor.id:
            return Cliente.objects.none()
        return filtro_real(*args, **kwargs)

    with patch.object(Cliente.objects, 'filter', side_effect=filtro):
        cliente = cliente_do_consumidor(consumidor)

    assert cliente.pk == por_email.pk
    # A transação continua utilizável depois da falha.
    assert Cliente.objects.count() == 2
