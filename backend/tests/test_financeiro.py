import pytest
from datetime import date, datetime, timezone as dt_timezone
from decimal import Decimal
from django.contrib.auth.models import User
from rest_framework.test import APIClient

from apps_work.agenda.models import Agendamento, AgendamentoServico, Pagamento as PagamentoAgenda
from apps_work.clientes.models import Cliente, ObjetoCliente, Pet
from apps_work.financeiro.models import Despesa, TransacaoCredito
from apps_work.financeiro.services import CaixaService, DespesaService, SaldoService
from apps_work.kanban.models import AtendimentoKanban, EtapaKanban, PagamentoKanban
from apps_work.kanban.services import AtendimentoKanbanService
from apps_work.servicos.models import Servico
from apps_work.usuarios.models import Colaborador
from rest_framework.exceptions import ValidationError


# ─── Fixtures ─────────────────────────────────────────────────────────────────

@pytest.fixture
def client_autenticado(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def cliente(patch_tenant_middleware):
    return Cliente.objects.create(nome='Ana Souza')


@pytest.fixture
def objeto_cliente(cliente):
    return Pet.objects.create(cliente=cliente, tipo='pet', nome='Fofão', especie='Gato')


@pytest.fixture
def etapa(patch_tenant_middleware):
    return EtapaKanban.objects.create(nome='Aguardando', ordem=0, cor='#F59E0B')


@pytest.fixture
def servico(patch_tenant_middleware):
    return Servico.objects.create(nome='Banho', duracao=30, preco='80.00')


@pytest.fixture
def atendimento(etapa, objeto_cliente, servico):
    return AtendimentoKanban.objects.create(etapa=etapa, objeto=objeto_cliente, servico=servico)


# ─── Model __str__ ────────────────────────────────────────────────────────────

@pytest.mark.django_db
class TestTransacaoCreditoStr:
    def test_str_credito(self, cliente):
        t = TransacaoCredito.objects.create(
            cliente=cliente, tipo='credito', valor='15.00', origem='troco'
        )
        assert 'Crédito' in str(t)
        assert '15.00' in str(t)

    def test_str_debito(self, cliente):
        t = TransacaoCredito.objects.create(
            cliente=cliente, tipo='debito', valor='10.00', origem='desconto_aplicado'
        )
        assert 'Débito' in str(t)


# ─── SaldoService ─────────────────────────────────────────────────────────────

@pytest.mark.django_db
class TestSaldoService:
    def test_saldo_cliente_sem_transacoes_retorna_zero(self, cliente):
        assert SaldoService().saldo(cliente.pk) == Decimal('0')

    def test_adicionar_troco_cria_transacao_credito(self, cliente, atendimento):
        SaldoService().adicionar_troco(cliente.pk, Decimal('10.00'), atendimento.pk)
        assert TransacaoCredito.objects.filter(cliente=cliente, tipo='credito').count() == 1
        assert SaldoService().saldo(cliente.pk) == Decimal('10.00')

    def test_aplicar_credito_cria_transacao_debito(self, cliente):
        TransacaoCredito.objects.create(
            cliente=cliente, tipo='credito', valor='50.00', origem='troco'
        )
        SaldoService().aplicar_credito(cliente.pk, Decimal('30.00'))
        assert SaldoService().saldo(cliente.pk) == Decimal('20.00')

    def test_aplicar_credito_saldo_insuficiente_lanca_erro(self, cliente):
        TransacaoCredito.objects.create(
            cliente=cliente, tipo='credito', valor='5.00', origem='troco'
        )
        with pytest.raises(ValidationError):
            SaldoService().aplicar_credito(cliente.pk, Decimal('10.00'))

    def test_saldo_acumula_multiplas_transacoes(self, cliente):
        TransacaoCredito.objects.create(cliente=cliente, tipo='credito', valor='20.00', origem='troco')
        TransacaoCredito.objects.create(cliente=cliente, tipo='credito', valor='15.00', origem='manual')
        TransacaoCredito.objects.create(cliente=cliente, tipo='debito', valor='10.00', origem='desconto_aplicado')
        assert SaldoService().saldo(cliente.pk) == Decimal('25.00')


# ─── SaldoService.registrar_taxa_cancelamento() ──────────────────────────────

@pytest.mark.django_db
class TestRegistrarTaxaCancelamento:
    def test_cria_transacao_debito_com_origem_taxa_cancelamento(self, cliente):
        SaldoService().registrar_taxa_cancelamento(cliente.pk, Decimal('20.00'), descricao='Cancelamento fora do prazo')
        transacao = TransacaoCredito.objects.get(cliente=cliente, origem='taxa_cancelamento')
        assert transacao.tipo == 'debito'
        assert transacao.valor == Decimal('20.00')
        assert transacao.descricao == 'Cancelamento fora do prazo'

    def test_permite_saldo_ficar_negativo_sem_lancar_erro(self, cliente):
        # Sem nenhum crédito prévio — ao contrário de aplicar_credito(), este
        # método não deve validar saldo disponível.
        SaldoService().registrar_taxa_cancelamento(cliente.pk, Decimal('20.00'))
        assert SaldoService().saldo(cliente.pk) == Decimal('-20.00')


# ─── AtendimentoKanbanService com crédito ────────────────────────────────────

@pytest.mark.django_db
class TestAtendimentoKanbanServiceCredito:
    def test_cobrar_com_credito_aplicado_soma_correta(self, atendimento, cliente):
        TransacaoCredito.objects.create(
            cliente=cliente, tipo='credito', valor='20.00', origem='troco'
        )
        pagamentos = [{'forma': 'pix', 'valor': '60.00'}]
        resultado = AtendimentoKanbanService().cobrar(
            atendimento, Decimal('0'), pagamentos, credito_aplicado=Decimal('20.00')
        )
        resultado.refresh_from_db()
        assert resultado.pago is True
        assert SaldoService().saldo(cliente.pk) == Decimal('0.00')

    def test_cobrar_com_troco_cria_credito_na_comanda(self, atendimento, cliente):
        pagamentos = [{'forma': 'dinheiro', 'valor': '80.00'}]
        AtendimentoKanbanService().cobrar(
            atendimento, Decimal('0'), pagamentos, troco_credito=Decimal('10.00')
        )
        assert SaldoService().saldo(cliente.pk) == Decimal('10.00')

    def test_cobrar_credito_insuficiente_lanca_erro(self, atendimento, cliente):
        pagamentos = [{'forma': 'pix', 'valor': '60.00'}]
        with pytest.raises(ValidationError):
            AtendimentoKanbanService().cobrar(
                atendimento, Decimal('0'), pagamentos, credito_aplicado=Decimal('20.00')
            )


# ─── SaldoClienteView ─────────────────────────────────────────────────────────

@pytest.mark.django_db
class TestSaldoClienteView:
    def test_get_saldo_retorna_200_e_saldo_zero(self, client_autenticado, cliente):
        response = client_autenticado.get(f'/api/v1/financeiro/clientes/{cliente.pk}/saldo/')
        assert response.status_code == 200
        assert response.data['saldo'] == '0.00'
        assert response.data['transacoes'] == []

    def test_get_saldo_retorna_transacoes(self, client_autenticado, cliente):
        TransacaoCredito.objects.create(
            cliente=cliente, tipo='credito', valor='25.00', origem='troco'
        )
        response = client_autenticado.get(f'/api/v1/financeiro/clientes/{cliente.pk}/saldo/')
        assert response.status_code == 200
        assert response.data['saldo'] == '25.00'
        assert len(response.data['transacoes']) == 1

    def test_get_saldo_nao_autenticado_retorna_401(self, patch_tenant_middleware, cliente):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get(f'/api/v1/financeiro/clientes/{cliente.pk}/saldo/')
        assert response.status_code == 401


# ─── CaixaService — filtro por colaborador ────────────────────────────────────

@pytest.fixture
def colaborador(patch_tenant_middleware):
    user = User.objects.create_user(
        username='colab@email.com', email='colab@email.com', password='senha123',
        first_name='Pedro', last_name='Costa',
    )
    return Colaborador.objects.create(user=user, role='colaborador')


@pytest.fixture
def agendamento_com_colaborador(patch_tenant_middleware, cliente, servico, colaborador):
    ag = Agendamento.objects.create(
        cliente=cliente,
        colaborador=colaborador,
        data_hora=datetime(2024, 6, 10, 9, 0, tzinfo=dt_timezone.utc),
        status='concluido',
    )
    AgendamentoServico.objects.create(agendamento=ag, servico=servico, preco_cobrado=servico.preco, desconto=0)
    PagamentoAgenda.objects.create(agendamento=ag, forma='pix', valor='80.00')
    return ag


@pytest.mark.django_db
class TestCaixaServiceColaborador:
    def test_sem_filtro_inclui_pagamento_kanban(self, atendimento):
        AtendimentoKanbanService().cobrar(atendimento, Decimal('0'), [{'forma': 'dinheiro', 'valor': '80.00'}])
        dados = CaixaService().obter_dados(date.today(), date.today())
        assert any(p['origem'] == 'kanban' for p in dados['pagamentos'])

    def test_sem_filtro_inclui_pagamento_agenda_com_colaborador_nome(self, agendamento_com_colaborador):
        dados = CaixaService().obter_dados(date(2024, 6, 10), date(2024, 6, 10))
        pagamento = next(p for p in dados['pagamentos'] if p['origem'] == 'agenda')
        assert pagamento['colaborador_nome'] == 'Pedro Costa'

    def test_kanban_sem_filtro_tem_colaborador_nome_vazio(self, atendimento):
        AtendimentoKanbanService().cobrar(atendimento, Decimal('0'), [{'forma': 'dinheiro', 'valor': '80.00'}])
        dados = CaixaService().obter_dados(date.today(), date.today())
        pagamento = next(p for p in dados['pagamentos'] if p['origem'] == 'kanban')
        assert pagamento['colaborador_nome'] == ''

    def test_filtro_por_colaborador_exclui_kanban(self, atendimento):
        AtendimentoKanbanService().cobrar(atendimento, Decimal('0'), [{'forma': 'dinheiro', 'valor': '80.00'}])
        dados = CaixaService().obter_dados(date.today(), date.today(), colaborador_id=999999)
        assert dados['pagamentos'] == []

    def test_filtro_por_colaborador_correto_retorna_pagamento(self, agendamento_com_colaborador, colaborador):
        dados = CaixaService().obter_dados(date(2024, 6, 10), date(2024, 6, 10), colaborador_id=colaborador.pk)
        assert len(dados['pagamentos']) == 1
        assert dados['pagamentos'][0]['origem'] == 'agenda'

    def test_filtro_por_outro_colaborador_nao_retorna_nada(self, agendamento_com_colaborador):
        outro_user = User.objects.create_user(username='outro@email.com', email='outro@email.com', password='senha123')
        outro = Colaborador.objects.create(user=outro_user, role='colaborador')
        dados = CaixaService().obter_dados(date(2024, 6, 10), date(2024, 6, 10), colaborador_id=outro.pk)
        assert dados['pagamentos'] == []


@pytest.mark.django_db
class TestCaixaViewColaborador:
    def test_filtro_colaborador_invalido_retorna_400(self, client_autenticado):
        response = client_autenticado.get('/api/v1/financeiro/caixa/?colaborador=abc')
        assert response.status_code == 400

    def test_filtro_colaborador_valido_retorna_200(self, client_autenticado, colaborador):
        response = client_autenticado.get(f'/api/v1/financeiro/caixa/?colaborador={colaborador.pk}')
        assert response.status_code == 200


# ─── Despesa ─────────────────────────────────────────────────────────────────

@pytest.fixture
def client_colaborador(patch_tenant_middleware, colaborador):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=colaborador.user)
    return client


def _despesa(descricao='Aluguel', valor='1000.00', categoria='aluguel', data=date(2024, 6, 10)):
    return Despesa.objects.create(descricao=descricao, valor=valor, categoria=categoria, data=data)


@pytest.mark.django_db
class TestDespesaService:
    def test_resumo_periodo_vazio_retorna_zeros(self, patch_tenant_middleware):
        resumo = DespesaService().resumo(date(2024, 6, 1), date(2024, 6, 30))
        assert resumo == {'total': '0.00', 'por_categoria': []}

    def test_resumo_soma_total_e_quebra_por_categoria(self, patch_tenant_middleware):
        _despesa(valor='800.00', categoria='aluguel', data=date(2024, 6, 5))
        _despesa(valor='200.00', categoria='agua_luz', data=date(2024, 6, 8))
        _despesa(valor='200.00', categoria='agua_luz', data=date(2024, 6, 20))

        resumo = DespesaService().resumo(date(2024, 6, 1), date(2024, 6, 30))

        assert resumo['total'] == '1200.00'
        # Ordenado do maior gasto para o menor.
        assert [c['categoria'] for c in resumo['por_categoria']] == ['aluguel', 'agua_luz']
        assert resumo['por_categoria'][0]['total'] == '800.00'
        assert resumo['por_categoria'][0]['percentual'] == 66
        assert resumo['por_categoria'][0]['categoria_label'] == 'Aluguel'

    def test_resumo_ignora_despesa_fora_do_periodo(self, patch_tenant_middleware):
        _despesa(valor='500.00', data=date(2024, 5, 31))
        _despesa(valor='300.00', data=date(2024, 6, 10))

        resumo = DespesaService().resumo(date(2024, 6, 1), date(2024, 6, 30))

        assert resumo['total'] == '300.00'


@pytest.mark.django_db
class TestDespesaAPI:
    def test_criar_despesa(self, client_autenticado):
        payload = {'descricao': 'Aluguel', 'valor': '1200.00', 'categoria': 'aluguel', 'data': '2024-06-10'}
        response = client_autenticado.post('/api/v1/financeiro/despesas/', payload)
        assert response.status_code == 201
        assert response.data['descricao'] == 'Aluguel'

    def test_listar_despesas_paginado(self, client_autenticado):
        _despesa()
        response = client_autenticado.get('/api/v1/financeiro/despesas/')
        assert response.status_code == 200
        assert response.data['count'] == 1
        assert len(response.data['results']) == 1

    def test_atualizar_despesa(self, client_autenticado):
        despesa = _despesa()
        response = client_autenticado.patch(f'/api/v1/financeiro/despesas/{despesa.pk}/', {'valor': '1500.00'})
        assert response.status_code == 200
        assert response.data['valor'] == '1500.00'

    def test_excluir_despesa(self, client_autenticado):
        despesa = _despesa()
        response = client_autenticado.delete(f'/api/v1/financeiro/despesas/{despesa.pk}/')
        assert response.status_code == 204
        assert not Despesa.objects.filter(pk=despesa.pk).exists()

    def test_filtro_por_periodo_exclui_fora_do_range(self, client_autenticado):
        _despesa(descricao='Dentro', data=date(2024, 6, 10))
        _despesa(descricao='Fora', data=date(2024, 7, 1))
        response = client_autenticado.get('/api/v1/financeiro/despesas/?data_inicio=2024-06-01&data_fim=2024-06-30')
        assert response.data['count'] == 1
        assert response.data['results'][0]['descricao'] == 'Dentro'

    def test_filtro_por_categoria(self, client_autenticado):
        _despesa(categoria='aluguel')
        _despesa(categoria='marketing')
        response = client_autenticado.get('/api/v1/financeiro/despesas/?categoria=marketing')
        assert response.data['count'] == 1
        assert response.data['results'][0]['categoria'] == 'marketing'

    def test_resumo_endpoint_retorna_total_e_quebra(self, client_autenticado):
        _despesa(valor='700.00', categoria='aluguel', data=date(2024, 6, 5))
        _despesa(valor='300.00', categoria='produtos', data=date(2024, 6, 6))
        response = client_autenticado.get('/api/v1/financeiro/despesas/resumo/?data_inicio=2024-06-01&data_fim=2024-06-30')
        assert response.status_code == 200
        assert response.data['total'] == '1000.00'
        assert len(response.data['por_categoria']) == 2

    def test_criar_com_valor_zero_retorna_400(self, client_autenticado):
        payload = {'descricao': 'Erro', 'valor': '0.00', 'categoria': 'outros', 'data': '2024-06-10'}
        response = client_autenticado.post('/api/v1/financeiro/despesas/', payload)
        assert response.status_code == 400

    def test_colaborador_comum_nao_pode_criar_despesa(self, client_colaborador):
        payload = {'descricao': 'Aluguel', 'valor': '1200.00', 'categoria': 'aluguel', 'data': '2024-06-10'}
        response = client_colaborador.post('/api/v1/financeiro/despesas/', payload)
        assert response.status_code == 403

    def test_nao_autenticado_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/v1/financeiro/despesas/')
        assert response.status_code == 401
