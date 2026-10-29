"""Resumo do painel por período e por profissional, com a trava do colaborador
(que vale também para o caixa)."""
from datetime import datetime, time, timedelta
from decimal import Decimal

import pytest
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient

from apps_work.agenda.models import Agendamento, AgendamentoServico, PagamentoAgendamento
from apps_work.clientes.models import Cliente
from apps_work.servicos.models import Servico
from apps_work.usuarios.models import Colaborador
from tenants.models import Membro


def _client(user):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=user)
    return client


@pytest.fixture
def cenario(patch_tenant_middleware, tenant, proprietario):
    """Dono e colaboradora atendendo hoje e ontem, com pagamentos efetivados."""
    dono = Colaborador.objects.create(user=proprietario)
    user_bia = User.objects.create_user(username='bia@x.com', email='bia@x.com', password='SenhaForte123!')
    Membro.objects.create(user=user_bia, tenant=tenant, papel='colaborador')
    bia = Colaborador.objects.create(user=user_bia)

    corte = Servico.objects.create(nome='Corte', nicho='cabeleireiro', duracao=30, preco='40.00')
    barba = Servico.objects.create(nome='Barba', nicho='barbearia', duracao=20, preco='20.00')
    ana = Cliente.objects.create(nome='Ana', telefone='11999990000')

    hoje = timezone.localdate()

    def concluido(colaborador, dia, servico, valor, hora=10):
        quando = timezone.make_aware(datetime.combine(dia, time(hora, 0)))
        ag = Agendamento.objects.create(cliente=ana, colaborador=colaborador, data_hora=quando, status='concluido')
        AgendamentoServico.objects.create(agendamento=ag, servico=servico, preco_cobrado=servico.preco)
        PagamentoAgendamento.objects.create(agendamento=ag, forma='pix', valor=Decimal(valor))
        return ag

    concluido(dono, hoje, corte, '40.00', hora=9)
    concluido(bia, hoje, barba, '20.00', hora=11)
    concluido(dono, hoje - timedelta(days=1), corte, '40.00')
    concluido(dono, hoje - timedelta(days=1), corte, '40.00', hora=14)
    # marcado para agora há pouco: aparece em "hoje", não conta como receita
    Agendamento.objects.create(
        cliente=ana, colaborador=bia, status='agendado',
        data_hora=timezone.make_aware(datetime.combine(hoje, time(17, 0))),
    )
    return {'dono': dono, 'bia': bia, 'user_bia': user_bia, 'hoje': hoje}


@pytest.mark.django_db
class TestResumoPorPeriodo:
    def test_sem_parametros_e_hoje_comparado_com_ontem(self, cenario, proprietario):
        corpo = _client(proprietario).get('/api/v1/dashboard/resumo/').json()

        hoje = cenario['hoje']
        assert corpo['periodo'] == {
            'data_inicio': hoje.isoformat(),
            'data_fim': hoje.isoformat(),
            'anterior_inicio': (hoje - timedelta(days=1)).isoformat(),
            'anterior_fim': (hoje - timedelta(days=1)).isoformat(),
        }
        assert corpo['colaborador'] is None
        assert corpo['kpis']['faturamento'] == '60.00'
        assert corpo['kpis']['atendimentos'] == 2
        assert corpo['kpis']['ticket_medio'] == '30.00'
        # ontem foram 80,00 em 2: -25% e 0%
        assert corpo['kpis']['faturamento_variacao'] == -25
        assert corpo['kpis']['atendimentos_variacao'] == 0
        assert corpo['kpis']['clientes_novos'] == 1
        assert [r['nome'] for r in corpo['ranking_servicos']] == ['Corte', 'Barba']
        assert [r['nicho'] for r in corpo['ranking_servicos']] == ['cabeleireiro', 'barbearia']
        assert [a['hora'] for a in corpo['agendamentos_hoje']] == ['17:00']
        # o próximo traz o que a tela precisa para abrir e chamar no WhatsApp
        proximo = corpo['agendamentos_hoje'][0]
        assert proximo['cliente_telefone'] == '11999990000'
        assert proximo['colaborador_nome'] == cenario['bia'].nome_exibido
        # hoje é um ponto só na série, com os mesmos números dos kpis
        assert corpo['serie'] == [{'data': hoje.isoformat(), 'faturamento': '60.00', 'atendimentos': 2}]

    def test_periodo_de_sete_dias_compara_com_os_sete_anteriores(self, cenario, proprietario):
        hoje = cenario['hoje']
        inicio = hoje - timedelta(days=6)
        corpo = _client(proprietario).get(
            f'/api/v1/dashboard/resumo/?data_inicio={inicio}&data_fim={hoje}',
        ).json()

        assert corpo['periodo']['anterior_inicio'] == (inicio - timedelta(days=7)).isoformat()
        assert corpo['periodo']['anterior_fim'] == (inicio - timedelta(days=1)).isoformat()
        assert corpo['kpis']['faturamento'] == '140.00'
        assert corpo['kpis']['atendimentos'] == 4
        # sem nada nos sete dias anteriores, não há base de comparação
        assert corpo['kpis']['faturamento_variacao'] is None
        # um ponto por dia, zerado nos dias sem nada, somando os kpis
        serie = corpo['serie']
        assert [p['data'] for p in serie] == [(inicio + timedelta(days=i)).isoformat() for i in range(7)]
        assert serie[-1] == {'data': hoje.isoformat(), 'faturamento': '60.00', 'atendimentos': 2}
        assert serie[-2]['faturamento'] == '80.00'
        assert serie[0] == {'data': inicio.isoformat(), 'faturamento': '0.00', 'atendimentos': 0}

    def test_filtro_por_profissional_so_conta_a_agenda_dele(self, cenario, proprietario):
        corpo = _client(proprietario).get(
            f"/api/v1/dashboard/resumo/?colaborador={cenario['bia'].id}",
        ).json()

        assert corpo['colaborador'] == cenario['bia'].id
        assert corpo['kpis']['faturamento'] == '20.00'
        assert corpo['kpis']['atendimentos'] == 1
        assert corpo['kpis']['clientes_novos'] is None
        assert [r['nome'] for r in corpo['ranking_servicos']] == ['Barba']
        assert len(corpo['agendamentos_hoje']) == 1

    def test_colaborador_comum_ve_so_o_proprio_mesmo_pedindo_outro(self, cenario):
        corpo = _client(cenario['user_bia']).get(
            f"/api/v1/dashboard/resumo/?colaborador={cenario['dono'].id}",
        ).json()

        assert corpo['colaborador'] == cenario['bia'].id
        assert corpo['kpis']['faturamento'] == '20.00'

    def test_colaborador_sem_perfil_recebe_404(self, patch_tenant_middleware, tenant):
        user = User.objects.create_user(username='novo@x.com', email='novo@x.com', password='SenhaForte123!')
        Membro.objects.create(user=user, tenant=tenant, papel='colaborador')

        response = _client(user).get('/api/v1/dashboard/resumo/')

        assert response.status_code == 404
        assert response.json()['code'] == 'sem_colaborador'

    def test_parametros_invalidos_retornam_400(self, cenario, proprietario):
        api = _client(proprietario)
        assert api.get('/api/v1/dashboard/resumo/?data_inicio=ontem').status_code == 400
        assert api.get('/api/v1/dashboard/resumo/?data_inicio=2026-10-10&data_fim=2026-10-01').status_code == 400
        assert api.get('/api/v1/dashboard/resumo/?colaborador=x').status_code == 400
        assert api.get('/api/v1/dashboard/resumo/?colaborador=x').json()['code'] == 'parametros_invalidos'

    def test_o_caixa_tem_a_mesma_trava(self, cenario):
        corpo = _client(cenario['user_bia']).get(
            f"/api/v1/financeiro/caixa/?colaborador={cenario['dono'].id}",
        ).json()

        assert corpo['kpis']['total'] == '20.00'
