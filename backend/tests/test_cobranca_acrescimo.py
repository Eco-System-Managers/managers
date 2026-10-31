"""A cobrança que respeita o combinado e registra o que foi feito (regra 9 do
modo esteira): o acréscimo com o motivo e a troca de serviço em comum acordo,
nos dois modos de agenda, e o espelho no agendamento do cliente."""
from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone
from rest_framework.test import APIClient

from apps_serv.consumidores.models import AgendamentoConsumidor, Consumidor
from apps_serv.consumidores.serializers import AgendamentoConsumidorSerializer
from apps_work.agenda.models import Agendamento, AgendamentoServico, PagamentoAgendamento
from apps_work.agenda.services import AgendamentoService, PendenciasCobrancaService
from apps_work.clientes.models import Cliente, Veiculo
from apps_work.dashboard.services import DashboardService
from apps_work.financeiro.services import CaixaService
from apps_work.kanban.models import PagamentoAtendimento
from apps_work.kanban.services import AtendimentoKanbanService, EtapaService
from apps_work.servicos.models import Servico
from apps_work.servicos.services import servicos_ativos
from core.excecoes import ErroDeNegocio

KANBAN = '/api/v1/kanban/atendimentos/'
AGENDA = '/api/v1/agendamentos/'


@pytest.fixture
def api(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def cliente(patch_tenant_middleware):
    return Cliente.objects.create(nome='Ana', telefone='11999990000')


@pytest.fixture
def carro(cliente):
    return Veiculo.objects.create(
        cliente=cliente, tipo='veiculo', placa='ABC1D23', marca='VW', modelo='Gol', cor='Prata', porte='carro',
    )


@pytest.fixture
def etapas(patch_tenant_middleware):
    return EtapaService().criar_etapas_padrao()


def _servico(nome, preco, nicho='lava_rapido', porte='', duracao=40, ativo=True):
    return Servico.objects.create(nome=nome, nicho=nicho, porte=porte, duracao=duracao, preco=preco, ativo=ativo)


@pytest.fixture
def lavagem(patch_tenant_middleware):
    return _servico('Lavagem', '40.00')


@pytest.fixture
def polimento(patch_tenant_middleware):
    return _servico('Polimento', '120.00', duracao=240)


@pytest.fixture
def atendimento(etapas, carro, lavagem):
    return AtendimentoKanbanService().criar(etapa=etapas[0], objeto_id=carro.pk, servico_id=lavagem.pk)


@pytest.fixture
def corte(patch_tenant_middleware):
    return _servico('Corte', '50.00', nicho='barbearia', duracao=30)


@pytest.fixture
def barba(patch_tenant_middleware):
    return _servico('Barba', '30.00', nicho='barbearia', duracao=20)


@pytest.fixture
def agendamento(cliente, corte):
    """Um corte de ontem, ainda por cobrar."""
    ag = Agendamento.objects.create(cliente=cliente, data_hora=timezone.now() - timedelta(days=1))
    AgendamentoServico.objects.create(agendamento=ag, servico=corte, preco_cobrado=corte.preco)
    return ag


@pytest.fixture
def consumidor(db):
    return Consumidor.objects.create(nome='Ana', email='ana@sm.com', telefone='11999990000', password='x')


def _pix(valor):
    return [{'forma': 'pix', 'valor': str(valor)}]


def _cobrar(api, url, registro, pagamentos, **extra):
    return api.post(f'{url}{registro.pk}/cobrar/', {'desconto': '0', 'pagamentos': pagamentos, **extra}, format='json')


def _espelho(consumidor, tenant, origem, agendamento_id, valor_total):
    """O agendamento como o app do cliente o guardou ao marcar."""
    return AgendamentoConsumidor.objects.create(
        consumidor=consumidor, schema_name=tenant.schema_name, agendamento_id=agendamento_id, origem=origem,
        negocio_nome='Empresa Teste', servicos=[], data_hora=timezone.now(), duracao_total=40,
        valor_total=valor_total, status='agendado',
    )


@pytest.mark.django_db
class TestAcrescimoNaEsteira:
    def test_o_acrescimo_entra_no_total(self, api, atendimento):
        resposta = _cobrar(api, KANBAN, atendimento, _pix('50.00'), acrescimo='10.00', acrescimo_motivo='tempo excedido')

        assert resposta.status_code == 200
        assert resposta.data['pago'] is True
        assert resposta.data['acrescimo'] == '10.00'
        assert resposta.data['acrescimo_motivo'] == 'tempo excedido'
        atendimento.refresh_from_db()
        assert atendimento.acrescimo == Decimal('10.00')
        assert atendimento.acrescimo_motivo == 'tempo excedido'

    def test_sem_o_acrescimo_na_soma_e_soma_invalida(self, api, atendimento):
        resposta = _cobrar(api, KANBAN, atendimento, _pix('40.00'), acrescimo='10.00')

        assert resposta.status_code == 400
        assert resposta.data['code'] == 'soma_invalida'
        atendimento.refresh_from_db()
        assert atendimento.pago is False
        assert atendimento.acrescimo == Decimal('0')

    def test_acrescimo_e_desconto_juntos(self, atendimento):
        AtendimentoKanbanService().cobrar(
            atendimento, Decimal('5'), _pix('45.00'), acrescimo=Decimal('10'), acrescimo_motivo='barro',
        )

        atendimento.refresh_from_db()
        assert atendimento.pago is True
        assert atendimento.desconto == Decimal('5.00')
        assert atendimento.acrescimo == Decimal('10.00')

    def test_sem_acrescimo_cobra_o_combinado(self, api, atendimento):
        resposta = _cobrar(api, KANBAN, atendimento, _pix('40.00'))

        assert resposta.status_code == 200
        assert resposta.data['acrescimo'] == '0.00'
        assert resposta.data['acrescimo_motivo'] == ''

    def test_acrescimo_negativo_e_recusado(self, api, atendimento):
        resposta = _cobrar(api, KANBAN, atendimento, _pix('30.00'), acrescimo='-10.00')

        assert resposta.status_code == 400
        assert 'acrescimo' in resposta.data['fields']

    def test_o_acrescimo_nao_muda_por_patch(self, api, atendimento):
        resposta = api.patch(f'{KANBAN}{atendimento.pk}/', {'acrescimo': '10.00', 'acrescimo_motivo': 'x'}, format='json')

        assert resposta.status_code == 200
        atendimento.refresh_from_db()
        assert atendimento.acrescimo == Decimal('0')
        assert atendimento.acrescimo_motivo == ''


@pytest.mark.django_db
class TestTrocaDeServicoNaEsteira:
    def test_troca_pelo_que_foi_feito(self, api, atendimento, polimento):
        resposta = _cobrar(api, KANBAN, atendimento, _pix('120.00'), servico_ids=[polimento.pk])

        assert resposta.status_code == 200
        assert resposta.data['servico'] == polimento.pk
        assert resposta.data['servico_nome'] == 'Polimento'
        assert resposta.data['servico_preco'] == '120.00'
        atendimento.refresh_from_db()
        assert atendimento.servico_id == polimento.pk
        assert atendimento.pago is True

    def test_a_soma_e_conferida_com_o_preco_do_novo(self, api, atendimento, lavagem, polimento):
        resposta = _cobrar(api, KANBAN, atendimento, _pix('40.00'), servico_ids=[polimento.pk])

        assert resposta.status_code == 400
        assert resposta.data['code'] == 'soma_invalida'
        atendimento.refresh_from_db()
        assert atendimento.servico_id == lavagem.pk
        assert atendimento.pago is False

    def test_troca_com_acrescimo(self, atendimento, polimento):
        AtendimentoKanbanService().cobrar(
            atendimento, Decimal('0'), _pix('130.00'), acrescimo=Decimal('10'), servico_ids=[polimento.pk],
        )

        atendimento.refresh_from_db()
        assert atendimento.servico_id == polimento.pk
        assert atendimento.acrescimo == Decimal('10.00')

    def test_servico_de_outro_porte_e_recusado(self, api, atendimento, lavagem):
        so_moto = _servico('Lavagem moto', '25.00', porte='moto')

        resposta = _cobrar(api, KANBAN, atendimento, _pix('25.00'), servico_ids=[so_moto.pk])

        assert resposta.status_code == 400
        assert resposta.data['code'] == 'servico_de_outro_porte'
        atendimento.refresh_from_db()
        assert atendimento.servico_id == lavagem.pk
        assert atendimento.pago is False

    def test_servico_do_porte_certo(self, api, atendimento):
        so_carro = _servico('Lavagem carro', '45.00', porte='carro')

        resposta = _cobrar(api, KANBAN, atendimento, _pix('45.00'), servico_ids=[so_carro.pk])

        assert resposta.status_code == 200
        assert resposta.data['servico'] == so_carro.pk

    def test_o_avulso_troca_sem_conferir_porte(self, etapas, lavagem):
        avulso = AtendimentoKanbanService().criar(
            etapa=etapas[0], objeto_id=None, servico_id=lavagem.pk, identificacao='Hilux branca',
        )
        so_moto = _servico('Lavagem moto', '25.00', porte='moto')

        AtendimentoKanbanService().cobrar(avulso, Decimal('0'), _pix('25.00'), servico_ids=[so_moto.pk])

        avulso.refresh_from_db()
        assert avulso.servico_id == so_moto.pk
        assert avulso.pago is True

    def test_mais_de_um_id_e_um_servico_so(self, api, atendimento, lavagem, polimento):
        resposta = _cobrar(api, KANBAN, atendimento, _pix('160.00'), servico_ids=[lavagem.pk, polimento.pk])

        assert resposta.status_code == 400
        assert resposta.data['code'] == 'um_servico_so'

    def test_servico_inexistente_ou_inativo_e_servico_invalido(self, api, atendimento):
        inativo = _servico('Antigo', '10.00', ativo=False)

        resposta = _cobrar(api, KANBAN, atendimento, _pix('10.00'), servico_ids=[inativo.pk])
        assert resposta.status_code == 400
        assert resposta.data['code'] == 'servico_invalido'

        resposta = _cobrar(api, KANBAN, atendimento, _pix('10.00'), servico_ids=[999999])
        assert resposta.status_code == 400
        assert resposta.data['code'] == 'servico_invalido'

    def test_lista_vazia_e_recusada(self, api, atendimento):
        resposta = _cobrar(api, KANBAN, atendimento, _pix('40.00'), servico_ids=[])

        assert resposta.status_code == 400
        assert 'servico_ids' in resposta.data['fields']


@pytest.mark.django_db
class TestDesfazerCobrancaNaEsteira:
    def test_zera_o_acrescimo_e_mantem_a_troca(self, api, atendimento, polimento):
        _cobrar(
            api, KANBAN, atendimento, _pix('130.00'),
            acrescimo='10.00', acrescimo_motivo='barro', servico_ids=[polimento.pk],
        )

        resposta = api.post(f'{KANBAN}{atendimento.pk}/desfazer_cobranca/')

        assert resposta.status_code == 200
        assert resposta.data['pago'] is False
        assert resposta.data['acrescimo'] == '0.00'
        assert resposta.data['acrescimo_motivo'] == ''
        assert resposta.data['servico'] == polimento.pk
        assert not PagamentoAtendimento.objects.exists()
        atendimento.refresh_from_db()
        assert atendimento.acrescimo == Decimal('0')
        assert atendimento.servico_id == polimento.pk


@pytest.mark.django_db
class TestAcrescimoNaAgenda:
    def test_o_acrescimo_entra_no_total(self, api, agendamento):
        resposta = _cobrar(
            api, AGENDA, agendamento, _pix('65.00'), desconto='5.00', acrescimo='20.00', acrescimo_motivo='tempo excedido',
        )

        assert resposta.status_code == 200
        assert resposta.data['status'] == 'concluido'
        assert resposta.data['acrescimo'] == '20.00'
        assert resposta.data['acrescimo_motivo'] == 'tempo excedido'
        agendamento.refresh_from_db()
        assert agendamento.acrescimo == Decimal('20.00')
        assert agendamento.desconto == Decimal('5.00')

    def test_sem_o_acrescimo_na_soma_e_soma_invalida(self, api, agendamento):
        resposta = _cobrar(api, AGENDA, agendamento, _pix('50.00'), acrescimo='20.00')

        assert resposta.status_code == 400
        assert resposta.data['code'] == 'soma_invalida'
        agendamento.refresh_from_db()
        assert agendamento.status == 'agendado'
        assert agendamento.acrescimo == Decimal('0')

    def test_pelo_service(self, agendamento):
        AgendamentoService().cobrar(
            agendamento, Decimal('0'), _pix('60.00'), acrescimo=Decimal('10'), acrescimo_motivo='tempo excedido',
        )

        agendamento.refresh_from_db()
        assert agendamento.status == 'concluido'
        assert agendamento.acrescimo == Decimal('10.00')
        assert agendamento.acrescimo_motivo == 'tempo excedido'
        assert PagamentoAgendamento.objects.filter(agendamento=agendamento).count() == 1

    def test_o_acrescimo_nao_muda_por_patch(self, api, agendamento):
        resposta = api.patch(f'{AGENDA}{agendamento.pk}/', {'acrescimo': '10.00'}, format='json')

        assert resposta.status_code == 200
        agendamento.refresh_from_db()
        assert agendamento.acrescimo == Decimal('0')

    def test_a_pendencia_segue_a_mesma_conta(self, api, agendamento):
        """A agenda não tem desfazer: quem volta um agendamento cobrado para
        confirmado o deixa pendente pelo que foi cobrado, acréscimo incluído."""
        _cobrar(api, AGENDA, agendamento, _pix('60.00'), acrescimo='10.00')
        api.patch(f'{AGENDA}{agendamento.pk}/', {'status': 'confirmado'}, format='json')

        pendencias = PendenciasCobrancaService().listar()

        assert [p['id'] for p in pendencias] == [agendamento.pk]
        assert pendencias[0]['valor'] == '60.00'


@pytest.mark.django_db
class TestTrocaDeServicoNaAgenda:
    def test_substitui_os_servicos_com_o_preco_atual(self, api, agendamento, corte, barba):
        # a tabela mudou depois de marcar: o congelado era 50, o atual é 60
        Servico.objects.filter(pk=corte.pk).update(preco='60.00')

        resposta = _cobrar(api, AGENDA, agendamento, _pix('90.00'), servico_ids=[corte.pk, barba.pk])

        assert resposta.status_code == 200
        itens = AgendamentoServico.objects.filter(agendamento=agendamento).order_by('pk')
        assert [(i.servico_id, i.preco_cobrado) for i in itens] == [
            (corte.pk, Decimal('60.00')), (barba.pk, Decimal('30.00')),
        ]
        assert sorted(s['servico_nome'] for s in resposta.data['servicos']) == ['Barba', 'Corte']

    def test_sem_troca_vale_o_preco_congelado(self, api, agendamento, corte):
        Servico.objects.filter(pk=corte.pk).update(preco='60.00')

        resposta = _cobrar(api, AGENDA, agendamento, _pix('50.00'))

        assert resposta.status_code == 200
        assert resposta.data['status'] == 'concluido'

    def test_a_soma_errada_desfaz_a_troca_junto(self, api, agendamento, corte, barba):
        resposta = _cobrar(api, AGENDA, agendamento, _pix('50.00'), servico_ids=[barba.pk])

        assert resposta.status_code == 400
        assert resposta.data['code'] == 'soma_invalida'
        assert list(AgendamentoServico.objects.filter(agendamento=agendamento).values_list('servico_id', flat=True)) == [
            corte.pk,
        ]

    def test_servico_inativo_e_servico_invalido(self, api, agendamento):
        inativo = _servico('Antigo', '10.00', nicho='barbearia', ativo=False)

        resposta = _cobrar(api, AGENDA, agendamento, _pix('10.00'), servico_ids=[inativo.pk])

        assert resposta.status_code == 400
        assert resposta.data['code'] == 'servico_invalido'

    def test_servicos_ativos_segue_a_ordem_e_nao_repete(self, corte, barba):
        assert servicos_ativos([barba.pk, corte.pk, barba.pk]) == [barba, corte]

        with pytest.raises(ErroDeNegocio) as erro:
            servicos_ativos([corte.pk, 999999])
        assert erro.value.code == 'servico_invalido'


@pytest.mark.django_db
class TestEspelhoNoAppDoCliente:
    """O que a cobrança decidiu chega ao AgendamentoConsumidor pelo sinal
    `cobranca_registrada`: o serviço feito de verdade, o acréscimo e o total."""

    def test_esteira(self, api, consumidor, tenant, atendimento, polimento):
        espelho = _espelho(consumidor, tenant, 'kanban', atendimento.pk, '40.00')
        outro_modo = _espelho(consumidor, tenant, 'agenda', atendimento.pk, '40.00')

        resposta = _cobrar(
            api, KANBAN, atendimento, _pix('125.00'),
            desconto='5.00', acrescimo='10.00', acrescimo_motivo='tempo excedido', servico_ids=[polimento.pk],
        )

        assert resposta.status_code == 200
        espelho.refresh_from_db()
        assert espelho.valor_total == Decimal('125.00')
        assert espelho.acrescimo == Decimal('10.00')
        assert espelho.acrescimo_motivo == 'tempo excedido'
        assert espelho.servicos == [
            {'nome': 'Polimento', 'nicho': 'lava_rapido', 'duracao': 240, 'preco': '120.00', 'taxa_cancelamento': '0.00'},
        ]
        # o id da esteira não bate num agendamento da agenda
        outro_modo.refresh_from_db()
        assert outro_modo.acrescimo == Decimal('0')
        assert outro_modo.valor_total == Decimal('40.00')

    def test_agenda(self, api, consumidor, tenant, agendamento, corte, barba):
        espelho = _espelho(consumidor, tenant, 'agenda', agendamento.pk, '50.00')

        resposta = _cobrar(
            api, AGENDA, agendamento, _pix('90.00'),
            acrescimo='10.00', acrescimo_motivo='tempo excedido', servico_ids=[corte.pk, barba.pk],
        )

        assert resposta.status_code == 200
        espelho.refresh_from_db()
        assert espelho.status == 'concluido'
        assert espelho.valor_total == Decimal('90.00')
        assert espelho.acrescimo == Decimal('10.00')
        assert espelho.acrescimo_motivo == 'tempo excedido'
        assert [(s['nome'], s['preco']) for s in espelho.servicos] == [('Corte', '50.00'), ('Barba', '30.00')]

    def test_sem_troca_o_retrato_e_o_preco_congelado(self, api, consumidor, tenant, agendamento, corte):
        Servico.objects.filter(pk=corte.pk).update(preco='60.00')
        espelho = _espelho(consumidor, tenant, 'agenda', agendamento.pk, '50.00')

        _cobrar(api, AGENDA, agendamento, _pix('50.00'))

        espelho.refresh_from_db()
        assert espelho.valor_total == Decimal('50.00')
        assert espelho.servicos[0]['preco'] == '50.00'

    def test_desfazer_na_esteira_limpa_o_espelho(self, api, consumidor, tenant, atendimento):
        espelho = _espelho(consumidor, tenant, 'kanban', atendimento.pk, '40.00')
        _cobrar(api, KANBAN, atendimento, _pix('50.00'), acrescimo='10.00', acrescimo_motivo='barro')

        api.post(f'{KANBAN}{atendimento.pk}/desfazer_cobranca/')

        espelho.refresh_from_db()
        assert espelho.acrescimo == Decimal('0')
        assert espelho.acrescimo_motivo == ''
        assert espelho.valor_total == Decimal('40.00')

    def test_os_campos_saem_no_app(self, consumidor, tenant):
        espelho = _espelho(consumidor, tenant, 'kanban', 1, '40.00')
        espelho.acrescimo = Decimal('10.00')
        espelho.acrescimo_motivo = 'tempo excedido'
        espelho.save(update_fields=['acrescimo', 'acrescimo_motivo'])

        dados = AgendamentoConsumidorSerializer(espelho).data

        assert dados['acrescimo'] == '10.00'
        assert dados['acrescimo_motivo'] == 'tempo excedido'
        assert dados['valor_total'] == '40.00'

    def test_o_do_balcao_nao_quebra(self, api, atendimento):
        """Sem contraparte no público, o handler simplesmente não acha nada."""
        resposta = _cobrar(api, KANBAN, atendimento, _pix('50.00'), acrescimo='10.00')

        assert resposta.status_code == 200
        assert not AgendamentoConsumidor.objects.exists()


@pytest.mark.django_db
class TestCaixaEPainel:
    def test_o_acrescimo_ja_entra_pelos_pagamentos(self, api, atendimento):
        _cobrar(api, KANBAN, atendimento, _pix('50.00'), acrescimo='10.00')
        hoje = timezone.localdate()

        caixa = CaixaService().obter_dados(hoje, hoje)
        painel = DashboardService().obter_resumo()

        assert caixa['kpis']['total'] == '50.00'
        assert caixa['kpis']['atendimentos'] == 1
        assert painel['kpis']['faturamento'] == '50.00'
