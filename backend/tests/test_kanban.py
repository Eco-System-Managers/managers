import pytest
from datetime import date, time
from decimal import Decimal
from rest_framework.test import APIClient

from apps_work.clientes.models import Cliente, ObjetoCliente, Pet
from apps_work.empresa.models import HorarioFuncionamento
from apps_work.kanban.models import AtendimentoKanban, EtapaKanban, PagamentoAtendimento
from apps_work.kanban.services import AtendimentoKanbanService, EtapaService, SlotService
from apps_work.servicos.models import Servico


@pytest.fixture
def client_autenticado(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def etapa(patch_tenant_middleware):
    return EtapaKanban.objects.create(nome='Aguardando', ordem=0, cor='#F59E0B')


@pytest.fixture
def etapa_destino(patch_tenant_middleware):
    return EtapaKanban.objects.create(nome='Em atendimento', ordem=1, cor='#3B82F6')


@pytest.fixture
def servico(patch_tenant_middleware):
    return Servico.objects.create(nome='Banho', duracao=30, preco='50.00')


@pytest.fixture
def objeto(patch_tenant_middleware):
    cliente = Cliente.objects.create(nome='Carlos Silva')
    return Pet.objects.create(cliente=cliente, tipo='pet', nome='Rex', especie='Cachorro')


@pytest.fixture
def atendimento(etapa, objeto, servico):
    return AtendimentoKanban.objects.create(etapa=etapa, objeto=objeto, servico=servico)


# --- __str__ ---

@pytest.mark.django_db
class TestKanbanModelStr:
    def test_str_etapa(self, etapa):
        assert str(etapa) == 'Aguardando'

    def test_str_atendimento(self, atendimento):
        assert str(atendimento) == f'{atendimento.objeto} — {atendimento.etapa}'

    def test_str_pagamento(self, atendimento):
        pagamento = PagamentoAtendimento.objects.create(
            atendimento=atendimento, forma='dinheiro', valor='50.00'
        )
        assert str(pagamento) == f'{atendimento} — dinheiro: R$50.00'


# --- Services ---

@pytest.mark.django_db
class TestEtapaKanbanService:
    def test_criar_etapas_padrao_cria_3_etapas(self, patch_tenant_middleware):
        etapas = EtapaService().criar_etapas_padrao()
        assert len(etapas) == 3
        assert EtapaKanban.objects.count() == 3

    def test_criar_etapas_padrao_nao_duplica_se_ja_existem(self, patch_tenant_middleware):
        EtapaKanban.objects.create(nome='Existente', ordem=0)
        etapas = EtapaService().criar_etapas_padrao()
        assert EtapaKanban.objects.count() == 1
        assert len(etapas) == 1

    def test_reordenar_atualiza_ordem_das_etapas(self, etapa, etapa_destino):
        EtapaService().reordenar([
            {'id': etapa.pk, 'ordem': 5},
            {'id': etapa_destino.pk, 'ordem': 10},
        ])
        assert EtapaKanban.objects.get(pk=etapa.pk).ordem == 5
        assert EtapaKanban.objects.get(pk=etapa_destino.pk).ordem == 10


@pytest.mark.django_db
class TestAtendimentoKanbanService:
    def test_criar_atendimento_vincula_etapa_objeto_servico(self, etapa, objeto, servico):
        atendimento = AtendimentoKanbanService().criar(
            etapa=etapa, objeto_id=objeto.pk, servico_id=servico.pk
        )
        assert atendimento.pk is not None
        assert atendimento.etapa == etapa
        assert atendimento.objeto_id == objeto.pk
        assert atendimento.servico == servico

    def test_criar_atendimento_objeto_inexistente_lanca_excecao(self, etapa, servico):
        with pytest.raises(ObjetoCliente.DoesNotExist):
            AtendimentoKanbanService().criar(
                etapa=etapa, objeto_id=99999, servico_id=servico.pk
            )

    def test_criar_atendimento_persiste_data_informada(self, etapa, objeto, servico):
        atendimento = AtendimentoKanbanService().criar(
            etapa=etapa, objeto_id=objeto.pk, servico_id=servico.pk, data=date(2026, 8, 10),
        )
        assert atendimento.data == date(2026, 8, 10)

    def test_criar_atendimento_sem_data_usa_hoje(self, etapa, objeto, servico):
        atendimento = AtendimentoKanbanService().criar(
            etapa=etapa, objeto_id=objeto.pk, servico_id=servico.pk,
        )
        assert atendimento.data == date.today()

    def test_criar_atendimento_no_mesmo_horario_lanca_erro(self, etapa, objeto, servico):
        from rest_framework.exceptions import ValidationError
        AtendimentoKanbanService().criar(
            etapa=etapa, objeto_id=objeto.pk, servico_id=servico.pk,
            data=date(2026, 8, 14), horario_entrada=time(8, 40),
        )
        with pytest.raises(ValidationError):
            AtendimentoKanbanService().criar(
                etapa=etapa, objeto_id=objeto.pk, servico_id=servico.pk,
                data=date(2026, 8, 14), horario_entrada=time(8, 40),
            )

    def test_criar_atendimento_mesmo_horario_dia_diferente_permite(self, etapa, objeto, servico):
        AtendimentoKanbanService().criar(
            etapa=etapa, objeto_id=objeto.pk, servico_id=servico.pk,
            data=date(2026, 8, 14), horario_entrada=time(8, 40),
        )
        atendimento = AtendimentoKanbanService().criar(
            etapa=etapa, objeto_id=objeto.pk, servico_id=servico.pk,
            data=date(2026, 8, 15), horario_entrada=time(8, 40),
        )
        assert atendimento.pk is not None

    def test_mover_atendimento_atualiza_etapa(self, atendimento, etapa_destino):
        resultado = AtendimentoKanbanService().mover(atendimento, etapa_destino)
        assert resultado.etapa == etapa_destino
        assert AtendimentoKanban.objects.get(pk=atendimento.pk).etapa == etapa_destino

    def test_cobrar_atualiza_desconto_pago_e_cria_pagamento(self, atendimento):
        pagamentos = [{'forma': 'pix', 'valor': '50.00'}]
        resultado = AtendimentoKanbanService().cobrar(atendimento, Decimal('0'), pagamentos)
        resultado.refresh_from_db()
        assert resultado.pago is True
        assert resultado.desconto == Decimal('0')
        assert PagamentoAtendimento.objects.filter(atendimento=resultado).count() == 1

    def test_cobrar_com_desconto_correto_marca_pago(self, atendimento):
        pagamentos = [{'forma': 'dinheiro', 'valor': '40.00'}]
        resultado = AtendimentoKanbanService().cobrar(atendimento, Decimal('10'), pagamentos)
        resultado.refresh_from_db()
        assert resultado.pago is True

    def test_cobrar_total_incorreto_lanca_erro(self, atendimento):
        from rest_framework.exceptions import ValidationError
        pagamentos = [{'forma': 'credito', 'valor': '10.00'}]
        with pytest.raises(ValidationError):
            AtendimentoKanbanService().cobrar(atendimento, Decimal('0'), pagamentos)


# --- API EtapaKanban ---

@pytest.mark.django_db
class TestEtapaKanbanAPI:
    def test_listar_etapas_retorna_200(self, client_autenticado, etapa):
        response = client_autenticado.get('/api/v1/kanban/etapas/')
        assert response.status_code == 200
        assert len(response.data['results']) == 1

    def test_criar_etapa_retorna_201(self, client_autenticado):
        payload = {'nome': 'Nova Etapa', 'ordem': 0, 'cor': '#FFFFFF'}
        response = client_autenticado.post('/api/v1/kanban/etapas/', payload)
        assert response.status_code == 201
        assert response.data['nome'] == 'Nova Etapa'

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/v1/kanban/etapas/')
        assert response.status_code == 401

    def test_reordenar_etapas_retorna_204(self, client_autenticado, etapa, etapa_destino):
        payload = {'ordem': [{'id': etapa.pk, 'ordem': 5}, {'id': etapa_destino.pk, 'ordem': 10}]}
        response = client_autenticado.post('/api/v1/kanban/etapas/reordenar/', payload, format='json')
        assert response.status_code == 204
        assert EtapaKanban.objects.get(pk=etapa.pk).ordem == 5

    def test_reordenar_com_payload_invalido_retorna_400(self, client_autenticado):
        response = client_autenticado.post('/api/v1/kanban/etapas/reordenar/', {'ordem': 'invalido'}, format='json')
        assert response.status_code == 400

    def test_deletar_etapa_retorna_204(self, client_autenticado, etapa):
        response = client_autenticado.delete(f'/api/v1/kanban/etapas/{etapa.id}/')
        assert response.status_code == 204
        assert EtapaKanban.objects.filter(pk=etapa.pk).count() == 0


# --- API AtendimentoKanban ---

@pytest.mark.django_db
class TestAtendimentoKanbanAPI:
    def test_listar_atendimentos_retorna_200(self, client_autenticado, atendimento):
        response = client_autenticado.get('/api/v1/kanban/atendimentos/')
        assert response.status_code == 200
        assert response.data['count'] == 1

    def test_quadro_do_dia_vem_no_mesmo_formato_paginado(self, client_autenticado, atendimento):
        """O formato não muda com ?data= (antes virava array): o client gerado
        do OpenAPI tem um tipo só para a rota."""
        import datetime
        hoje = datetime.date.today().isoformat()
        response = client_autenticado.get(f'/api/v1/kanban/atendimentos/?data={hoje}')
        assert set(response.data) >= {'count', 'next', 'previous', 'results'}

    def test_historico_por_cliente_vem_paginado(self, client_autenticado, atendimento):
        cliente_id = atendimento.objeto.cliente.id
        response = client_autenticado.get(f'/api/v1/kanban/atendimentos/?cliente={cliente_id}')
        assert set(response.data) >= {'count', 'next', 'previous', 'results'}

    def test_historico_por_cliente_traz_no_maximo_vinte(self, client_autenticado, etapa, objeto, servico, atendimento):
        for _ in range(24):
            AtendimentoKanban.objects.create(etapa=etapa, objeto=objeto, servico=servico)
        cliente_id = atendimento.objeto.cliente.id
        response = client_autenticado.get(f'/api/v1/kanban/atendimentos/?cliente={cliente_id}')
        assert response.data['count'] == 25
        assert len(response.data['results']) == 20
        assert response.data['next'] is not None

    def test_dia_cheio_sai_inteiro_mesmo_passando_de_vinte(self, client_autenticado, etapa, objeto, servico):
        import datetime
        hoje = datetime.date.today()
        for _ in range(25):
            AtendimentoKanban.objects.create(etapa=etapa, objeto=objeto, servico=servico, data=hoje)
        # O quadro monta as colunas com o dia inteiro: pede página grande e
        # confere que não há próxima — senão card sumiria do quadro sem erro.
        response = client_autenticado.get(f'/api/v1/kanban/atendimentos/?data={hoje.isoformat()}&page_size=100')
        assert len(response.data['results']) == 25
        assert response.data['next'] is None

    def test_criar_atendimento_retorna_201(self, client_autenticado, etapa, objeto, servico):
        payload = {'etapa': etapa.pk, 'objeto': objeto.pk, 'servico': servico.pk}
        response = client_autenticado.post('/api/v1/kanban/atendimentos/', payload)
        assert response.status_code == 201
        assert response.data['etapa_nome'] == etapa.nome
        assert response.data['cliente_nome'] == objeto.cliente.nome
        assert response.data['servico_nome'] == servico.nome

    def test_criar_atendimento_com_data_persiste_data(self, client_autenticado, etapa, objeto, servico):
        payload = {'etapa': etapa.pk, 'objeto': objeto.pk, 'servico': servico.pk, 'data': '2026-09-01'}
        response = client_autenticado.post('/api/v1/kanban/atendimentos/', payload)
        assert response.status_code == 201
        assert response.data['data'] == '2026-09-01'

    def test_listar_filtra_por_data_e_nao_por_criado_em(self, client_autenticado, etapa, objeto, servico):
        AtendimentoKanban.objects.create(etapa=etapa, objeto=objeto, servico=servico, data=date(2026, 9, 1))
        AtendimentoKanban.objects.create(etapa=etapa, objeto=objeto, servico=servico, data=date(2026, 9, 2))
        response = client_autenticado.get('/api/v1/kanban/atendimentos/?data=2026-09-01')
        assert response.status_code == 200
        assert len(response.data['results']) == 1

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/v1/kanban/atendimentos/')
        assert response.status_code == 401

    def test_mover_atendimento_retorna_200(self, client_autenticado, atendimento, etapa_destino):
        response = client_autenticado.post(
            f'/api/v1/kanban/atendimentos/{atendimento.pk}/mover/',
            {'etapa_id': etapa_destino.pk},
        )
        assert response.status_code == 200
        assert response.data['etapa'] == etapa_destino.pk

    def test_mover_sem_etapa_id_retorna_400(self, client_autenticado, atendimento):
        response = client_autenticado.post(
            f'/api/v1/kanban/atendimentos/{atendimento.pk}/mover/',
            {},
        )
        assert response.status_code == 400

    def test_mover_com_etapa_inexistente_retorna_404(self, client_autenticado, atendimento):
        response = client_autenticado.post(
            f'/api/v1/kanban/atendimentos/{atendimento.pk}/mover/',
            {'etapa_id': 99999},
        )
        assert response.status_code == 404

    def test_criar_atendimento_com_horario_entrada(self, client_autenticado, etapa, objeto, servico):
        payload = {'etapa': etapa.pk, 'objeto': objeto.pk, 'servico': servico.pk, 'horario_entrada': '08:00'}
        response = client_autenticado.post('/api/v1/kanban/atendimentos/', payload)
        assert response.status_code == 201
        assert response.data['horario_entrada'] == '08:00:00'

    def test_criar_atendimento_no_mesmo_horario_retorna_400(self, client_autenticado, etapa, objeto, servico):
        payload = {'etapa': etapa.pk, 'objeto': objeto.pk, 'servico': servico.pk, 'horario_entrada': '08:40', 'data': '2026-08-14'}
        client_autenticado.post('/api/v1/kanban/atendimentos/', payload)
        response = client_autenticado.post('/api/v1/kanban/atendimentos/', payload)
        assert response.status_code == 400
        assert response.data['code'] == 'horario_ocupado'

    def test_pago_default_false_ao_criar(self, client_autenticado, etapa, objeto, servico):
        payload = {'etapa': etapa.pk, 'objeto': objeto.pk, 'servico': servico.pk}
        response = client_autenticado.post('/api/v1/kanban/atendimentos/', payload)
        assert response.status_code == 201
        assert response.data['pago'] is False
        assert AtendimentoKanban.objects.get(pk=response.data['id']).pago is False

    def test_atualizar_pago_via_patch_persiste_no_banco(self, client_autenticado, atendimento):
        response = client_autenticado.patch(
            f'/api/v1/kanban/atendimentos/{atendimento.pk}/', {'pago': True}, format='json'
        )
        assert response.status_code == 200
        assert response.data['pago'] is True
        assert AtendimentoKanban.objects.get(pk=atendimento.pk).pago is True

    def test_serializer_expoe_pago(self, client_autenticado, atendimento):
        response = client_autenticado.get('/api/v1/kanban/atendimentos/')
        assert response.status_code == 200
        assert 'pago' in response.data['results'][0]

    def test_serializer_expoe_servico_duracao(self, client_autenticado, atendimento):
        response = client_autenticado.get('/api/v1/kanban/atendimentos/')
        assert response.status_code == 200
        assert response.data['results'][0]['servico_duracao'] == atendimento.servico.duracao

    def test_serializer_expoe_cliente_telefone(self, client_autenticado, atendimento):
        response = client_autenticado.get('/api/v1/kanban/atendimentos/')
        assert response.status_code == 200
        assert 'cliente_telefone' in response.data['results'][0]

    def test_filtrar_por_cliente_retorna_apenas_do_cliente(self, client_autenticado, etapa, servico, atendimento):
        outro_cliente = Cliente.objects.create(nome='Maria Souza')
        outro_objeto = Pet.objects.create(cliente=outro_cliente, tipo='pet', nome='Fifi', especie='Gato')
        AtendimentoKanban.objects.create(etapa=etapa, objeto=outro_objeto, servico=servico)

        cliente_id = atendimento.objeto.cliente.id
        response = client_autenticado.get(f'/api/v1/kanban/atendimentos/?cliente={cliente_id}')
        assert response.status_code == 200
        assert response.data['count'] == 1
        assert response.data['results'][0]['id'] == atendimento.pk

    def test_filtrar_por_cliente_inexistente_retorna_lista_vazia(self, client_autenticado, atendimento):
        response = client_autenticado.get('/api/v1/kanban/atendimentos/?cliente=99999')
        assert response.status_code == 200
        assert response.data['count'] == 0

    def test_filtrar_por_data_retorna_atendimentos_do_dia(self, client_autenticado, etapa, objeto, servico):
        import datetime
        hoje = datetime.date.today().isoformat()
        response = client_autenticado.get(f'/api/v1/kanban/atendimentos/?data={hoje}')
        assert response.status_code == 200

    def test_cobrar_sem_pagamentos_retorna_400(self, client_autenticado, atendimento):
        payload = {'desconto': '0', 'pagamentos': []}
        response = client_autenticado.post(
            f'/api/v1/kanban/atendimentos/{atendimento.pk}/cobrar/',
            payload,
            format='json',
        )
        assert response.status_code == 400
        assert response.data['code'] == 'sem_pagamentos'

    def test_cobrar_com_total_correto_retorna_200_e_marca_pago(self, client_autenticado, atendimento):
        payload = {
            'desconto': '0',
            'pagamentos': [{'forma': 'pix', 'valor': '50.00'}],
        }
        response = client_autenticado.post(
            f'/api/v1/kanban/atendimentos/{atendimento.pk}/cobrar/',
            payload,
            format='json',
        )
        assert response.status_code == 200
        assert response.data['pago'] is True

    def test_cobrar_com_total_incorreto_retorna_400(self, client_autenticado, atendimento):
        payload = {
            'desconto': '0',
            'pagamentos': [{'forma': 'dinheiro', 'valor': '1.00'}],
        }
        response = client_autenticado.post(
            f'/api/v1/kanban/atendimentos/{atendimento.pk}/cobrar/',
            payload,
            format='json',
        )
        assert response.status_code == 400

    def test_desfazer_cobranca_atendimento_nao_pago_retorna_400(self, client_autenticado, atendimento):
        response = client_autenticado.post(
            f'/api/v1/kanban/atendimentos/{atendimento.pk}/desfazer_cobranca/',
        )
        assert response.status_code == 400
        assert response.data['code'] == 'nao_pago'

    def test_desfazer_cobranca_atendimento_pago_retorna_200(self, client_autenticado, atendimento):
        atendimento.pago = True
        atendimento.save(update_fields=['pago'])

        response = client_autenticado.post(
            f'/api/v1/kanban/atendimentos/{atendimento.pk}/desfazer_cobranca/',
        )
        assert response.status_code == 200
        assert response.data['pago'] is False


# --- SlotService ---

@pytest.fixture
def horario_segunda(patch_tenant_middleware):
    # Segunda-feira = dia 0, com capacidade 3 em 3 horas → intervalo de 60 min
    return HorarioFuncionamento.objects.create(
        dia=0, abertura='08:00', fechamento='11:00', ativo=True, capacidade=3
    )


@pytest.mark.django_db
class TestSlotService:
    def test_gera_slots_corretos_para_dia_com_horario(self, horario_segunda):
        # 2026-06-15 é uma segunda-feira
        slots = SlotService().gerar_slots(date(2026, 6, 15))
        assert len(slots) == 3
        assert slots[0] == {'horario': '08:00', 'disponivel': True}
        assert slots[1] == {'horario': '09:00', 'disponivel': True}
        assert slots[2] == {'horario': '10:00', 'disponivel': True}

    def test_retorna_vazio_para_dia_sem_horario(self, patch_tenant_middleware):
        # Nenhum HorarioFuncionamento cadastrado
        slots = SlotService().gerar_slots(date(2026, 6, 15))
        assert slots == []

    def test_retorna_vazio_para_dia_inativo(self, patch_tenant_middleware):
        HorarioFuncionamento.objects.create(dia=0, abertura='08:00', fechamento='18:00', ativo=False, capacidade=10)
        slots = SlotService().gerar_slots(date(2026, 6, 15))
        assert slots == []

    def test_retorna_vazio_sem_capacidade_definida(self, patch_tenant_middleware):
        HorarioFuncionamento.objects.create(dia=0, abertura='08:00', fechamento='18:00', ativo=True, capacidade=None)
        slots = SlotService().gerar_slots(date(2026, 6, 15))
        assert slots == []

    def test_marca_slot_ocupado_quando_ha_atendimento(self, patch_tenant_middleware, etapa, objeto, servico):
        hoje = date.today()
        HorarioFuncionamento.objects.create(
            dia=hoje.weekday(), abertura='08:00', fechamento='11:00', ativo=True, capacidade=3
        )
        AtendimentoKanban.objects.create(
            etapa=etapa, objeto=objeto, servico=servico, horario_entrada=time(8, 0), data=hoje,
        )
        slots = SlotService().gerar_slots(hoje)
        assert slots[0] == {'horario': '08:00', 'disponivel': False}
        assert slots[1]['disponivel'] is True
        assert slots[2]['disponivel'] is True

    def test_retorna_vazio_quando_fechamento_antes_da_abertura(self, patch_tenant_middleware):
        HorarioFuncionamento.objects.create(
            dia=0, abertura='09:00', fechamento='08:00', ativo=True, capacidade=5
        )
        slots = SlotService().gerar_slots(date(2026, 6, 15))
        assert slots == []

    def test_retorna_vazio_quando_intervalo_calculado_e_zero(self, patch_tenant_middleware):
        HorarioFuncionamento.objects.create(
            dia=0, abertura='08:00', fechamento='08:01', ativo=True, capacidade=3
        )
        slots = SlotService().gerar_slots(date(2026, 6, 15))
        assert slots == []

    def test_loop_interrompido_quando_horario_ultrapassa_fechamento(self, patch_tenant_middleware):
        # total_minutos=5, capacidade=6 → intervalo=round(5/6)=1, 6ª iteração quebra o loop
        HorarioFuncionamento.objects.create(
            dia=0, abertura='08:00', fechamento='08:05', ativo=True, capacidade=6
        )
        slots = SlotService().gerar_slots(date(2026, 6, 15))
        assert len(slots) == 5
        assert slots[0]['horario'] == '08:00'

    def test_slot_de_outro_dia_nao_afeta_disponibilidade(self, horario_segunda, etapa, objeto, servico):
        # Atendimento agendado para terça (2026-06-16) não deve bloquear slots de segunda (2026-06-15)
        AtendimentoKanban.objects.create(
            etapa=etapa, objeto=objeto, servico=servico, horario_entrada=time(8, 0), data=date(2026, 6, 16),
        )
        slots = SlotService().gerar_slots(date(2026, 6, 15))
        assert all(s['disponivel'] for s in slots)


# --- API Slots ---

@pytest.mark.django_db
class TestSlotsAPI:
    def test_sem_parametro_data_retorna_400(self, client_autenticado):
        response = client_autenticado.get('/api/v1/kanban/slots/')
        assert response.status_code == 400

    def test_data_invalida_retorna_400(self, client_autenticado):
        response = client_autenticado.get('/api/v1/kanban/slots/?data=nao-e-data')
        assert response.status_code == 400

    def test_dia_sem_horario_retorna_lista_vazia(self, client_autenticado):
        response = client_autenticado.get('/api/v1/kanban/slots/?data=2026-06-15')
        assert response.status_code == 200
        assert response.data == []

    def test_retorna_slots_do_dia(self, client_autenticado, horario_segunda):
        response = client_autenticado.get('/api/v1/kanban/slots/?data=2026-06-15')
        assert response.status_code == 200
        assert len(response.data) == 3
        assert response.data[0]['horario'] == '08:00'
        assert response.data[0]['disponivel'] is True

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/v1/kanban/slots/?data=2026-06-15')
        assert response.status_code == 401
