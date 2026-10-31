"""O avulso da esteira: o cliente que chega e pede "lava aí", sem cadastro.
O atendimento nasce sem veículo nem pet, só com a identificação; ocupa vaga,
entra no caixa e não tem comanda."""
from datetime import date, time
from decimal import Decimal

import pytest
from django.utils import timezone
from rest_framework.test import APIClient

from apps_work.agenda.services import PendenciasCobrancaService
from apps_work.clientes.models import Cliente, Veiculo
from apps_work.empresa.models import EmpresaConfig, HorarioFuncionamento
from apps_work.financeiro.models import TransacaoCredito
from apps_work.financeiro.services import SaldoService
from apps_work.kanban.models import AtendimentoKanban, PagamentoAtendimento
from apps_work.kanban.services import AtendimentoKanbanService, CapacidadeService, EtapaService
from apps_work.servicos.models import Servico
from core.excecoes import ErroDeNegocio

SEGUNDA = date(2026, 6, 15)  # uma segunda-feira
URL = '/api/v1/kanban/atendimentos/'


@pytest.fixture
def api(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def lava_rapido(patch_tenant_middleware):
    return EmpresaConfig.objects.create(pk=1, nichos=['lava_rapido'], tipo_agenda='kanban', tipo_objeto='veiculo')


@pytest.fixture
def etapas(patch_tenant_middleware):
    return EtapaService().criar_etapas_padrao()


@pytest.fixture
def lavagem(patch_tenant_middleware):
    return Servico.objects.create(nome='Lavagem', nicho='lava_rapido', duracao=40, preco='40.00')


@pytest.fixture
def carro(patch_tenant_middleware):
    cliente = Cliente.objects.create(nome='Ana', telefone='11999990000')
    return Veiculo.objects.create(
        cliente=cliente, tipo='veiculo', placa='ABC1D23', marca='VW', modelo='Gol', cor='Branco', porte='carro',
    )


def _avulso(etapas, lavagem, identificacao='Hilux branca', data=SEGUNDA, **extra):
    return AtendimentoKanbanService().criar(
        etapa=etapas[0], objeto_id=None, servico_id=lavagem.pk, identificacao=identificacao, data=data, **extra,
    )


def _com_carro(etapas, carro, lavagem, data=SEGUNDA, **extra):
    return AtendimentoKanbanService().criar(
        etapa=etapas[0], objeto_id=carro.pk, servico_id=lavagem.pk, data=data, **extra,
    )


def _cobrar(api, atendimento, pagamentos, **extra):
    return api.post(f'{URL}{atendimento.pk}/cobrar/', {'desconto': '0', 'pagamentos': pagamentos, **extra}, format='json')


@pytest.mark.django_db
class TestCriarAvulso:
    def test_pelo_service(self, etapas, lavagem):
        atendimento = _avulso(etapas, lavagem)

        assert atendimento.pk
        assert atendimento.objeto is None
        assert atendimento.avulso is True
        assert atendimento.identificacao == 'Hilux branca'
        assert atendimento.cliente is None
        assert atendimento.rotulo == 'Hilux branca'
        assert str(atendimento) == f'Hilux branca — {etapas[0]}'

    def test_com_carro_nao_e_avulso(self, etapas, carro, lavagem):
        atendimento = _com_carro(etapas, carro, lavagem)

        assert atendimento.avulso is False
        assert atendimento.cliente == carro.cliente
        assert atendimento.rotulo == 'Ana'
        assert str(atendimento) == f'{atendimento.objeto} — {etapas[0]}'

    def test_pela_api(self, api, etapas, lavagem):
        resposta = api.post(
            URL, {'etapa': etapas[0].pk, 'servico': lavagem.pk, 'identificacao': 'ABC-1234', 'data': '2026-06-15'},
            format='json',
        )

        assert resposta.status_code == 201
        assert resposta.data['avulso'] is True
        assert resposta.data['identificacao'] == 'ABC-1234'
        assert resposta.data['objeto'] is None
        assert resposta.data['objeto_detalhe'] is None
        assert resposta.data['cliente_nome'] is None
        assert resposta.data['cliente_telefone'] is None
        assert resposta.data['servico_nome'] == 'Lavagem'
        assert AtendimentoKanban.objects.get(pk=resposta.data['id']).objeto_id is None

    def test_pela_api_com_objeto_nulo_explicito(self, api, etapas, lavagem):
        resposta = api.post(
            URL, {'etapa': etapas[0].pk, 'objeto': None, 'servico': lavagem.pk, 'identificacao': 'Moto preta'},
            format='json',
        )

        assert resposta.status_code == 201
        assert resposta.data['avulso'] is True

    def test_pela_api_com_carro_sai_com_o_cliente(self, api, etapas, carro, lavagem):
        resposta = api.post(
            URL, {'etapa': etapas[0].pk, 'objeto': carro.pk, 'servico': lavagem.pk, 'data': '2026-06-15'},
            format='json',
        )

        assert resposta.status_code == 201
        assert resposta.data['avulso'] is False
        assert resposta.data['identificacao'] == ''
        assert resposta.data['cliente_nome'] == 'Ana'
        assert resposta.data['cliente_telefone'] == '11999990000'
        assert resposta.data['objeto_detalhe']['id'] == carro.pk

    def test_sem_objeto_nem_identificacao_e_recusado(self, api, etapas, lavagem):
        resposta = api.post(URL, {'etapa': etapas[0].pk, 'servico': lavagem.pk, 'data': '2026-06-15'}, format='json')

        assert resposta.status_code == 400
        assert resposta.data['code'] == 'avulso_sem_identificacao'
        assert not AtendimentoKanban.objects.exists()

    def test_identificacao_so_de_espacos_nao_vale(self, etapas, lavagem):
        with pytest.raises(ErroDeNegocio) as erro:
            _avulso(etapas, lavagem, identificacao='   ')

        assert erro.value.code == 'avulso_sem_identificacao'
        assert not AtendimentoKanban.objects.exists()

    def test_o_porte_so_e_conferido_com_objeto(self, lava_rapido, etapas, carro):
        so_moto = Servico.objects.create(nome='Lavagem moto', nicho='lava_rapido', porte='moto', duracao=20, preco='25.00')

        # o avulso não tem porte com o que comparar
        assert _avulso(etapas, so_moto).pk
        # com o carro a trava continua
        with pytest.raises(ErroDeNegocio) as erro:
            _com_carro(etapas, carro, so_moto)
        assert erro.value.code == 'servico_de_outro_porte'


@pytest.mark.django_db
class TestAvulsoOcupaVaga:
    @pytest.fixture
    def expediente(self, patch_tenant_middleware):
        """Segunda das 8h às 11h, 1 por vez, até 2 no dia."""
        return HorarioFuncionamento.objects.create(
            dia=0, abertura=time(8), fechamento=time(11), ativo=True, capacidade=2, vagas=1,
        )

    def test_conta_no_maximo_do_dia(self, expediente, etapas, carro, lavagem):
        _avulso(etapas, lavagem)
        _avulso(etapas, lavagem, identificacao='Moto preta')

        assert CapacidadeService().do_dia(SEGUNDA)['ocupados'] == 2
        with pytest.raises(ErroDeNegocio) as erro:
            _com_carro(etapas, carro, lavagem, horario_entrada=time(9))
        assert erro.value.code == 'dia_lotado'

    def test_com_hora_tira_a_hora_da_grade(self, expediente, etapas, lavagem):
        _avulso(etapas, lavagem, horario_entrada=time(9))

        livres = [h.strftime('%H:%M') for h in CapacidadeService().livres(SEGUNDA, 40)]

        assert '08:00' in livres
        assert '09:00' not in livres

    def test_o_dono_recebe_o_avulso_mesmo_lotado(self, expediente, etapas, lavagem):
        _avulso(etapas, lavagem)
        _avulso(etapas, lavagem, identificacao='Moto preta')

        with pytest.raises(ErroDeNegocio):
            _avulso(etapas, lavagem, identificacao='Uno verde')
        assert _avulso(etapas, lavagem, identificacao='Uno verde', ignorar_limite=True).pk


@pytest.mark.django_db
class TestCobrarAvulso:
    def test_sem_credito_entra_como_qualquer_outro(self, api, etapas, lavagem):
        atendimento = _avulso(etapas, lavagem)

        resposta = _cobrar(api, atendimento, [{'forma': 'pix', 'valor': '40.00'}])

        assert resposta.status_code == 200
        assert resposta.data['pago'] is True
        assert resposta.data['avulso'] is True
        assert PagamentoAtendimento.objects.filter(atendimento=atendimento).count() == 1
        assert not TransacaoCredito.objects.exists()

    def test_credito_aplicado_e_recusado(self, api, etapas, lavagem):
        atendimento = _avulso(etapas, lavagem)

        resposta = _cobrar(api, atendimento, [{'forma': 'pix', 'valor': '30.00'}], credito_aplicado='10.00')

        assert resposta.status_code == 400
        assert resposta.data['code'] == 'avulso_sem_credito'
        atendimento.refresh_from_db()
        assert atendimento.pago is False
        assert not PagamentoAtendimento.objects.exists()

    def test_troco_em_credito_e_recusado(self, api, etapas, lavagem):
        atendimento = _avulso(etapas, lavagem)

        resposta = _cobrar(api, atendimento, [{'forma': 'dinheiro', 'valor': '40.00'}], troco_credito='10.00')

        assert resposta.status_code == 400
        assert resposta.data['code'] == 'avulso_sem_credito'
        assert not TransacaoCredito.objects.exists()

    def test_pelo_service(self, etapas, lavagem):
        atendimento = _avulso(etapas, lavagem)

        with pytest.raises(ErroDeNegocio) as erro:
            AtendimentoKanbanService().cobrar(
                atendimento, Decimal('0'), [{'forma': 'pix', 'valor': '40.00'}], troco_credito=Decimal('5'),
            )

        assert erro.value.code == 'avulso_sem_credito'

    def test_com_carro_o_troco_vai_para_a_comanda(self, etapas, carro, lavagem):
        """O controle: a regra é só do avulso."""
        atendimento = _com_carro(etapas, carro, lavagem)

        AtendimentoKanbanService().cobrar(
            atendimento, Decimal('0'), [{'forma': 'dinheiro', 'valor': '40.00'}], troco_credito=Decimal('10'),
        )

        assert SaldoService().saldo(carro.cliente_id) == Decimal('10.00')

    def test_desfazer_cobranca_do_avulso(self, api, etapas, lavagem):
        atendimento = _avulso(etapas, lavagem)
        _cobrar(api, atendimento, [{'forma': 'pix', 'valor': '40.00'}])

        resposta = api.post(f'{URL}{atendimento.pk}/desfazer_cobranca/')

        assert resposta.status_code == 200
        assert resposta.data['pago'] is False
        assert not PagamentoAtendimento.objects.exists()


@pytest.mark.django_db
class TestEditarAvulso:
    def test_tirar_o_objeto_sem_identificacao_e_recusado(self, api, etapas, carro, lavagem):
        atendimento = _com_carro(etapas, carro, lavagem)

        resposta = api.patch(f'{URL}{atendimento.pk}/', {'objeto': None}, format='json')

        assert resposta.status_code == 400
        assert resposta.data['code'] == 'avulso_sem_identificacao'
        atendimento.refresh_from_db()
        assert atendimento.objeto_id == carro.pk

    def test_virar_avulso_com_identificacao(self, api, etapas, carro, lavagem):
        atendimento = _com_carro(etapas, carro, lavagem)

        resposta = api.patch(
            f'{URL}{atendimento.pk}/', {'objeto': None, 'identificacao': 'Gol prata'}, format='json',
        )

        assert resposta.status_code == 200
        assert resposta.data['avulso'] is True
        assert resposta.data['cliente_nome'] is None

    def test_apagar_a_identificacao_do_avulso_e_recusado(self, api, etapas, lavagem):
        atendimento = _avulso(etapas, lavagem)

        resposta = api.patch(f'{URL}{atendimento.pk}/', {'identificacao': ''}, format='json')

        assert resposta.status_code == 400
        assert resposta.data['code'] == 'avulso_sem_identificacao'

    def test_vincular_o_carro_depois_confere_o_porte(self, api, lava_rapido, etapas, carro):
        so_moto = Servico.objects.create(nome='Lavagem moto', nicho='lava_rapido', porte='moto', duracao=20, preco='25.00')
        atendimento = _avulso(etapas, so_moto)

        resposta = api.patch(f'{URL}{atendimento.pk}/', {'objeto': carro.pk}, format='json')

        assert resposta.status_code == 400
        assert resposta.data['code'] == 'servico_de_outro_porte'

    def test_vincular_o_carro_depois(self, api, etapas, carro, lavagem):
        atendimento = _avulso(etapas, lavagem)

        resposta = api.patch(f'{URL}{atendimento.pk}/', {'objeto': carro.pk}, format='json')

        assert resposta.status_code == 200
        assert resposta.data['avulso'] is False
        assert resposta.data['cliente_nome'] == 'Ana'

    def test_marcar_e_desfazer_falta_no_avulso(self, api, etapas, lavagem):
        atendimento = _avulso(etapas, lavagem)

        resposta = api.post(f'{URL}{atendimento.pk}/marcar_falta/')
        assert resposta.status_code == 200
        assert resposta.data['faltou'] is True

        resposta = api.post(f'{URL}{atendimento.pk}/desfazer_falta/')
        assert resposta.status_code == 200
        assert resposta.data['faltou'] is False

    def test_mover_o_avulso(self, api, etapas, lavagem):
        atendimento = _avulso(etapas, lavagem)

        resposta = api.post(f'{URL}{atendimento.pk}/mover/', {'etapa_id': etapas[2].pk})

        assert resposta.status_code == 200
        assert resposta.data['pronto_em'] is not None


@pytest.mark.django_db
class TestAvulsoNoMeioDosOutros:
    """O que lê o atendimento fora do quadro não pode cair em `None.cliente`."""

    def test_quadro_do_dia(self, api, etapas, carro, lavagem):
        _com_carro(etapas, carro, lavagem)
        _avulso(etapas, lavagem)

        resposta = api.get(URL, {'data': '2026-06-15', 'page_size': 100})

        assert resposta.status_code == 200
        assert resposta.data['count'] == 2
        cards = {(r['cliente_nome'], r['identificacao'], r['avulso']) for r in resposta.data['results']}
        assert cards == {('Ana', '', False), (None, 'Hilux branca', True)}

    def test_historico_do_cliente_nao_traz_o_avulso(self, api, etapas, carro, lavagem):
        _com_carro(etapas, carro, lavagem)
        _avulso(etapas, lavagem)

        resposta = api.get(URL, {'cliente': carro.cliente_id})

        assert resposta.status_code == 200
        assert resposta.data['count'] == 1
        assert resposta.data['results'][0]['avulso'] is False

    def test_caixa(self, api, etapas, carro, lavagem):
        for atendimento in (_com_carro(etapas, carro, lavagem), _avulso(etapas, lavagem)):
            AtendimentoKanbanService().cobrar(atendimento, Decimal('0'), [{'forma': 'pix', 'valor': '40.00'}])
        hoje = timezone.localdate().isoformat()

        resposta = api.get('/api/v1/financeiro/caixa/', {'data_inicio': hoje, 'data_fim': hoje})

        assert resposta.status_code == 200
        assert resposta.data['kpis']['total'] == '80.00'
        assert resposta.data['kpis']['atendimentos'] == 2
        assert sorted(p['cliente_nome'] for p in resposta.data['pagamentos']) == ['Ana', 'Hilux branca']

    def test_painel_de_hoje(self, api, lava_rapido, etapas, carro, lavagem):
        hoje = timezone.localdate()
        _com_carro(etapas, carro, lavagem, data=hoje)
        _avulso(etapas, lavagem, data=hoje)

        resposta = api.get('/api/v1/dashboard/resumo/')

        assert resposta.status_code == 200
        assert resposta.data['tipo_agenda'] == 'kanban'
        de_hoje = {(a['cliente_nome'], a['cliente_telefone']) for a in resposta.data['agendamentos_hoje']}
        assert de_hoje == {('Ana', '11999990000'), ('Hilux branca', '')}

    def test_pendencias(self, api, etapas, carro, lavagem):
        _com_carro(etapas, carro, lavagem, data=date(2026, 6, 10))
        _avulso(etapas, lavagem, data=date(2026, 6, 10))

        pendencias = PendenciasCobrancaService().listar(SEGUNDA)

        assert {(p['cliente_id'], p['cliente_nome']) for p in pendencias} == {
            (carro.cliente_id, 'Ana'), (None, 'Hilux branca'),
        }

        # e a rota devolve o nulo sem quebrar
        resposta = api.get('/api/v1/agenda/pendencias/')
        assert resposta.status_code == 200
        assert any(p['cliente_id'] is None and p['cliente_nome'] == 'Hilux branca' for p in resposta.data)
