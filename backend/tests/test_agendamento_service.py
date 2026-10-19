import pytest
from decimal import Decimal
from datetime import timedelta
from unittest.mock import patch

from django.db import connection
from django.utils import timezone
from django_tenants.utils import schema_context

from apps_serv.consumidores.models import AgendamentoConsumidor, VinculoConsumidor
from apps_serv.consumidores.services import RegistroConsumidorService
from apps_serv.vitrine.models import NegocioPublico
from apps_serv.vitrine.services import (
    AgendamentoTenantService, CancelarAgendamentoService, CrossTenantQueryService, VincularNegocioService,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def consumidor_registrado(db):
    from apps_serv.consumidores.models import Consumidor
    Consumidor.objects.filter(email='cliente@agendamento.com').delete()
    consumidor = RegistroConsumidorService().registrar(
        nome='Cliente Teste',
        email='cliente@agendamento.com',
        senha='SenhaForte123!',
    )
    return consumidor


@pytest.fixture
def negocio_publico(db, tenant):
    connection.set_schema_to_public()
    NegocioPublico.objects.filter(schema_name=tenant.schema_name).delete()
    return NegocioPublico.objects.create(
        schema_name=tenant.schema_name,
        nome=tenant.name,
        nicho='Barbearia',
        latitude='-23.550000',
        longitude='-46.633000',
        ativo=True,
    )


@pytest.fixture
def servico_no_tenant(tenant):
    with schema_context(tenant.schema_name):
        from apps_work.servicos.models import Servico
        return Servico.objects.create(
            nome='Corte',
            duracao=30,
            preco=Decimal('50.00'),
            ativo=True,
        )


@pytest.fixture
def dois_servicos_no_tenant(tenant):
    with schema_context(tenant.schema_name):
        from apps_work.servicos.models import Servico
        s1 = Servico.objects.create(nome='Corte', duracao=30, preco=Decimal('50.00'), ativo=True)
        s2 = Servico.objects.create(nome='Barba', duracao=20, preco=Decimal('30.00'), ativo=True)
        return s1, s2


@pytest.fixture
def negocio_publico_kanban(db, tenant):
    connection.set_schema_to_public()
    NegocioPublico.objects.filter(schema_name=tenant.schema_name).delete()
    return NegocioPublico.objects.create(
        schema_name=tenant.schema_name,
        nome=tenant.name,
        nicho='Banho e tosa',
        latitude='-23.550000',
        longitude='-46.633000',
        ativo=True,
        tipo_agenda='kanban',
    )


@pytest.fixture
def etapa_no_tenant(tenant):
    with schema_context(tenant.schema_name):
        from apps_work.kanban.models import EtapaKanban
        return EtapaKanban.objects.create(nome='Aguardando', ordem=0)


@pytest.fixture
def objeto_consumidor_pet(consumidor_registrado):
    from apps_serv.consumidores.models import ObjetoConsumidor
    return ObjetoConsumidor.objects.create(
        consumidor=consumidor_registrado, tipo='pet',
        nome_exibicao='Rex (Cachorro)',
        dados={'nome': 'Rex', 'especie': 'Cachorro', 'porte': 'Médio'},
    )


# ---------------------------------------------------------------------------
# AgendamentoTenantService.criar()
# ---------------------------------------------------------------------------

@pytest.mark.django_db(transaction=True)
class TestAgendamentoTenantServiceCriar:

    def test_cria_agendamento(
        self, tenant, consumidor_registrado, negocio_publico, servico_no_tenant
    ):
        ag = AgendamentoTenantService().criar(
            schema_name=tenant.schema_name,
            consumidor=consumidor_registrado,
            servico_ids=[servico_no_tenant.id],
            data_hora=timezone.now() + timedelta(hours=2),
        )

        assert ag.valor_total == servico_no_tenant.preco
        assert ag.status == 'agendado'
        assert ag.consumidor == consumidor_registrado

    def test_cria_agendamento_com_multiplos_servicos(
        self, tenant, consumidor_registrado, negocio_publico, dois_servicos_no_tenant
    ):
        s1, s2 = dois_servicos_no_tenant
        valor_esperado = s1.preco + s2.preco

        ag = AgendamentoTenantService().criar(
            schema_name=tenant.schema_name,
            consumidor=consumidor_registrado,
            servico_ids=[s1.id, s2.id],
            data_hora=timezone.now() + timedelta(hours=2),
        )

        assert ag.valor_total == valor_esperado
        assert len(ag.servicos) == 2

    def test_cria_cliente_no_schema_do_tenant(
        self, tenant, consumidor_registrado, negocio_publico, servico_no_tenant
    ):
        AgendamentoTenantService().criar(
            schema_name=tenant.schema_name,
            consumidor=consumidor_registrado,
            servico_ids=[servico_no_tenant.id],
            data_hora=timezone.now() + timedelta(hours=2),
        )

        with schema_context(tenant.schema_name):
            from apps_work.clientes.models import Cliente
            assert Cliente.objects.filter(email=consumidor_registrado.email).exists()

    def test_nao_duplica_cliente_existente_no_tenant(
        self, tenant, consumidor_registrado, negocio_publico, servico_no_tenant
    ):
        svc = AgendamentoTenantService()

        svc.criar(
            schema_name=tenant.schema_name,
            consumidor=consumidor_registrado,
            servico_ids=[servico_no_tenant.id],
            data_hora=timezone.now() + timedelta(hours=2),
        )
        svc.criar(
            schema_name=tenant.schema_name,
            consumidor=consumidor_registrado,
            servico_ids=[servico_no_tenant.id],
            data_hora=timezone.now() + timedelta(hours=4),
        )

        with schema_context(tenant.schema_name):
            from apps_work.clientes.models import Cliente
            assert Cliente.objects.filter(email=consumidor_registrado.email).count() == 1

    def test_registra_snapshot_dos_servicos(
        self, tenant, consumidor_registrado, negocio_publico, servico_no_tenant
    ):
        ag = AgendamentoTenantService().criar(
            schema_name=tenant.schema_name,
            consumidor=consumidor_registrado,
            servico_ids=[servico_no_tenant.id],
            data_hora=timezone.now() + timedelta(hours=2),
        )

        assert len(ag.servicos) == 1
        snap = ag.servicos[0]
        assert snap['nome'] == servico_no_tenant.nome
        assert snap['duracao'] == servico_no_tenant.duracao
        assert float(snap['preco']) == float(servico_no_tenant.preco)

    def test_registra_snapshot_com_taxa_cancelamento_configurada(
        self, tenant, consumidor_registrado, negocio_publico
    ):
        with schema_context(tenant.schema_name):
            from apps_work.servicos.models import Servico
            servico = Servico.objects.create(
                nome='Corte com taxa', duracao=30, preco=Decimal('100.00'),
                taxa_cancelamento_tipo='percentual', taxa_cancelamento_valor=Decimal('20'),
                ativo=True,
            )

        ag = AgendamentoTenantService().criar(
            schema_name=tenant.schema_name,
            consumidor=consumidor_registrado,
            servico_ids=[servico.id],
            data_hora=timezone.now() + timedelta(hours=2),
        )

        assert ag.valor_taxa_cancelamento == Decimal('20.00')
        assert ag.servicos[0]['taxa_cancelamento'] == 20.0

    def test_servico_invalido_levanta_value_error(
        self, tenant, consumidor_registrado, negocio_publico
    ):
        with pytest.raises(ValueError, match='serviço'):
            AgendamentoTenantService().criar(
                schema_name=tenant.schema_name,
                consumidor=consumidor_registrado,
                servico_ids=[99999],
                data_hora=timezone.now() + timedelta(hours=2),
            )

    def test_servico_inativo_nao_e_incluido(
        self, tenant, consumidor_registrado, negocio_publico
    ):
        with schema_context(tenant.schema_name):
            from apps_work.servicos.models import Servico
            inativo = Servico.objects.create(
                nome='Inativo', duracao=30, preco=Decimal('50.00'), ativo=False
            )

        with pytest.raises(ValueError, match='serviço'):
            AgendamentoTenantService().criar(
                schema_name=tenant.schema_name,
                consumidor=consumidor_registrado,
                servico_ids=[inativo.id],
                data_hora=timezone.now() + timedelta(hours=2),
            )

    def test_cria_vinculo_automaticamente_no_primeiro_agendamento(
        self, tenant, consumidor_registrado, negocio_publico, servico_no_tenant
    ):
        AgendamentoTenantService().criar(
            schema_name=tenant.schema_name,
            consumidor=consumidor_registrado,
            servico_ids=[servico_no_tenant.id],
            data_hora=timezone.now() + timedelta(hours=2),
        )

        assert VinculoConsumidor.objects.filter(
            consumidor=consumidor_registrado, schema_name=tenant.schema_name, ativo=True
        ).exists()

    def test_agendamento_reativa_vinculo_desvinculado(
        self, tenant, consumidor_registrado, negocio_publico, servico_no_tenant
    ):
        vinculo = VinculoConsumidor.objects.create(
            consumidor=consumidor_registrado, schema_name=tenant.schema_name,
            ativo=False, desvinculado_em=timezone.now(),
        )

        AgendamentoTenantService().criar(
            schema_name=tenant.schema_name,
            consumidor=consumidor_registrado,
            servico_ids=[servico_no_tenant.id],
            data_hora=timezone.now() + timedelta(hours=2),
        )

        vinculo.refresh_from_db()
        assert vinculo.ativo is True
        assert vinculo.desvinculado_em is None

    def test_segundo_agendamento_nao_duplica_vinculo(
        self, tenant, consumidor_registrado, negocio_publico, servico_no_tenant
    ):
        svc = AgendamentoTenantService()
        svc.criar(
            schema_name=tenant.schema_name, consumidor=consumidor_registrado,
            servico_ids=[servico_no_tenant.id], data_hora=timezone.now() + timedelta(hours=2),
        )
        svc.criar(
            schema_name=tenant.schema_name, consumidor=consumidor_registrado,
            servico_ids=[servico_no_tenant.id], data_hora=timezone.now() + timedelta(hours=4),
        )

        assert VinculoConsumidor.objects.filter(
            consumidor=consumidor_registrado, schema_name=tenant.schema_name
        ).count() == 1


# ---------------------------------------------------------------------------
# VincularNegocioService.garantir_vinculo()
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestGarantirVinculo:
    def test_cria_vinculo_quando_nao_existe(self, tenant, consumidor_registrado):
        vinculo = VincularNegocioService().garantir_vinculo(tenant.schema_name, consumidor_registrado)
        assert vinculo.ativo is True
        assert VinculoConsumidor.objects.filter(
            consumidor=consumidor_registrado, schema_name=tenant.schema_name
        ).count() == 1

    def test_nao_lanca_erro_quando_ja_ativo(self, tenant, consumidor_registrado):
        VinculoConsumidor.objects.create(consumidor=consumidor_registrado, schema_name=tenant.schema_name)
        # Não deve lançar ValueError, diferente de vincular()
        vinculo = VincularNegocioService().garantir_vinculo(tenant.schema_name, consumidor_registrado)
        assert vinculo.ativo is True

    def test_reativa_vinculo_inativo(self, tenant, consumidor_registrado):
        VinculoConsumidor.objects.create(
            consumidor=consumidor_registrado, schema_name=tenant.schema_name,
            ativo=False, desvinculado_em=timezone.now(),
        )
        VincularNegocioService().garantir_vinculo(tenant.schema_name, consumidor_registrado)

        vinculo = VinculoConsumidor.objects.get(consumidor=consumidor_registrado, schema_name=tenant.schema_name)
        assert vinculo.ativo is True
        assert vinculo.desvinculado_em is None

    def test_cria_cliente_visivel_e_notificacao(self, tenant, consumidor_registrado):
        VincularNegocioService().garantir_vinculo(tenant.schema_name, consumidor_registrado)

        with schema_context(tenant.schema_name):
            from apps_work.clientes.models import Cliente
            from apps_work.notificacoes.models import Notificacao

            cliente = Cliente.objects.get(email=consumidor_registrado.email)
            assert cliente.visivel is True
            assert cliente.nome == consumidor_registrado.nome

            notificacao = Notificacao.objects.get(cliente=cliente)
            assert notificacao.tipo == 'cliente_vinculado'
            assert consumidor_registrado.nome in notificacao.titulo


# ---------------------------------------------------------------------------
# VincularNegocioService.vincular() / desvincular()
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestVincularDesvincular:
    def test_vincular_cria_cliente_visivel_no_tenant(self, tenant, consumidor_registrado):
        VincularNegocioService().vincular(tenant.schema_name, consumidor_registrado)

        with schema_context(tenant.schema_name):
            from apps_work.clientes.models import Cliente
            cliente = Cliente.objects.get(email=consumidor_registrado.email)
            assert cliente.visivel is True
            assert cliente.telefone == consumidor_registrado.telefone

    def test_vincular_de_novo_sincroniza_dados_do_consumidor(self, tenant, consumidor_registrado):
        with schema_context(tenant.schema_name):
            from apps_work.clientes.models import Cliente
            Cliente.objects.create(
                nome='Nome Antigo', email=consumidor_registrado.email,
                telefone='0000-0000', visivel=False,
            )

        VincularNegocioService().garantir_vinculo(tenant.schema_name, consumidor_registrado)

        with schema_context(tenant.schema_name):
            cliente = Cliente.objects.get(email=consumidor_registrado.email)
            assert cliente.nome == consumidor_registrado.nome
            assert cliente.telefone == consumidor_registrado.telefone
            assert cliente.visivel is True
            # não deve ter duplicado o registro
            assert Cliente.objects.filter(email=consumidor_registrado.email).count() == 1

    def test_desvincular_esconde_cliente_sem_apagar(self, tenant, consumidor_registrado):
        VincularNegocioService().vincular(tenant.schema_name, consumidor_registrado)
        VincularNegocioService().desvincular(tenant.schema_name, consumidor_registrado)

        with schema_context(tenant.schema_name):
            from apps_work.clientes.models import Cliente
            from apps_work.notificacoes.models import Notificacao

            cliente = Cliente.objects.get(email=consumidor_registrado.email)
            assert cliente.visivel is False

            notificacao = Notificacao.objects.filter(tipo='cliente_desvinculado').get()
            assert consumidor_registrado.nome in notificacao.titulo

    def test_desvincular_sem_vinculo_ativo_lanca_erro(self, tenant, consumidor_registrado):
        with pytest.raises(ValueError, match='Vínculo não encontrado'):
            VincularNegocioService().desvincular(tenant.schema_name, consumidor_registrado)


# ---------------------------------------------------------------------------
# CancelarAgendamentoService — prazo dinâmico por duração
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestCancelarPrazoDinamico:
    """Verifica que o prazo de cancelamento sem taxa varia com a duração do serviço."""

    def _consumidor_registrado(self, email):
        return RegistroConsumidorService().registrar(
            nome='Teste', email=email, senha='SenhaForte123!',
        )

    def _criar_ag(self, consumidor, data_hora, duracao, valor_taxa_cancelamento=Decimal('0')):
        from unittest.mock import patch
        with patch('apps_serv.vitrine.services.schema_context'), \
             patch('apps_work.agenda.models.Agendamento'):
            return consumidor.agendamentos.create(
                schema_name='fake',
                agendamento_id=1,
                negocio_nome='X',
                servicos=[],
                data_hora=data_hora,
                duracao_total=duracao,
                valor_total=Decimal('100.00'),
                valor_taxa_cancelamento=valor_taxa_cancelamento,
                status='agendado',
            )

    def test_duracao_ate_30min_prazo_6h(self, db):
        consumidor = self._consumidor_registrado('prazo6h@teste.com')
        ag = self._criar_ag(consumidor, timezone.now() + timedelta(hours=10), duracao=30)

        from unittest.mock import patch
        with patch('apps_serv.vitrine.services.schema_context'), \
             patch('apps_work.agenda.models.Agendamento'):
            resultado = CancelarAgendamentoService().cancelar(ag, consumidor)

        assert resultado['taxa'] == 0.0

    def test_duracao_ate_90min_prazo_12h(self, db):
        consumidor = self._consumidor_registrado('prazo12h@teste.com')
        # 60min: prazo 12h; agendamento em 13h = dentro do prazo
        ag = self._criar_ag(consumidor, timezone.now() + timedelta(hours=13), duracao=60)

        from unittest.mock import patch
        with patch('apps_serv.vitrine.services.schema_context'), \
             patch('apps_work.agenda.models.Agendamento'):
            resultado = CancelarAgendamentoService().cancelar(ag, consumidor)

        assert resultado['taxa'] == 0.0

    def test_duracao_acima_90min_prazo_24h(self, db):
        consumidor = self._consumidor_registrado('prazo24h@teste.com')
        # 120min: prazo 24h; agendamento em 25h = dentro do prazo
        ag = self._criar_ag(consumidor, timezone.now() + timedelta(hours=25), duracao=120)

        from unittest.mock import patch
        with patch('apps_serv.vitrine.services.schema_context'), \
             patch('apps_work.agenda.models.Agendamento'):
            resultado = CancelarAgendamentoService().cancelar(ag, consumidor)

        assert resultado['taxa'] == 0.0

    def test_cancelamento_fora_do_prazo_sem_taxa_configurada_nao_gera_pendencia(self, db):
        consumidor = self._consumidor_registrado('taxa@teste.com')
        # Duração 30min: prazo 6h; agendamento em 3h = fora do prazo, mas o
        # serviço não tinha taxa_cancelamento configurada (valor_taxa_cancelamento=0).
        ag = self._criar_ag(consumidor, timezone.now() + timedelta(hours=3), duracao=30)

        from unittest.mock import patch
        with patch('apps_serv.vitrine.services.schema_context'), \
             patch('apps_work.agenda.models.Agendamento'):
            resultado = CancelarAgendamentoService().cancelar(ag, consumidor)

        assert resultado['taxa'] == 0.0

    def test_cancelamento_outro_consumidor_levanta_permission_error(self, db):
        c1 = self._consumidor_registrado('c1@teste.com')
        c2 = self._consumidor_registrado('c2@teste.com')
        ag = self._criar_ag(c1, timezone.now() + timedelta(hours=10), duracao=30)

        with pytest.raises(PermissionError):
            CancelarAgendamentoService().cancelar(ag, c2)


# ---------------------------------------------------------------------------
# CancelarAgendamentoService — taxa configurada no serviço, cobrada fora do prazo
# ---------------------------------------------------------------------------

@pytest.mark.django_db(transaction=True)
class TestCancelarComTaxaConfigurada:
    """Fluxo completo (via AgendamentoTenantService.criar) com um serviço que
    tem taxa_cancelamento configurada, cancelado fora do prazo."""

    def test_cancela_fora_do_prazo_registra_pendencia_no_tenant(
        self, tenant, consumidor_registrado, negocio_publico
    ):
        with schema_context(tenant.schema_name):
            from apps_work.servicos.models import Servico
            servico = Servico.objects.create(
                nome='Corte com taxa', duracao=30, preco=Decimal('100.00'),
                taxa_cancelamento_tipo='percentual', taxa_cancelamento_valor=Decimal('20'),
                ativo=True,
            )

        # Duração 30min → prazo 6h; agendamento em 3h = fora do prazo
        ag = AgendamentoTenantService().criar(
            schema_name=tenant.schema_name,
            consumidor=consumidor_registrado,
            servico_ids=[servico.id],
            data_hora=timezone.now() + timedelta(hours=3),
        )
        assert ag.valor_taxa_cancelamento == Decimal('20.00')

        resultado = CancelarAgendamentoService().cancelar(ag, consumidor_registrado)

        assert resultado['taxa'] == 20.0

        with schema_context(tenant.schema_name):
            from apps_work.financeiro.models import TransacaoCredito
            from apps_work.clientes.models import Cliente

            cliente = Cliente.objects.get(email=consumidor_registrado.email)
            transacao = TransacaoCredito.objects.get(cliente=cliente, origem='taxa_cancelamento')
            assert transacao.tipo == 'debito'
            assert transacao.valor == Decimal('20.00')


# ---------------------------------------------------------------------------
# AgendamentoTenantService.criar() -- negócio em modo Kanban
# ---------------------------------------------------------------------------

@pytest.mark.django_db(transaction=True)
class TestAgendamentoTenantServiceCriarKanban:
    def test_cria_atendimento_kanban_com_origem_correta(
        self, tenant, consumidor_registrado, negocio_publico_kanban, servico_no_tenant,
        etapa_no_tenant, objeto_consumidor_pet,
    ):
        data_hora = timezone.now() + timedelta(hours=5)
        ag = AgendamentoTenantService().criar(
            schema_name=tenant.schema_name,
            consumidor=consumidor_registrado,
            servico_ids=[servico_no_tenant.id],
            data_hora=data_hora,
            objeto_id=objeto_consumidor_pet.id,
        )
        assert ag.origem == 'kanban'

        with schema_context(tenant.schema_name):
            from apps_work.kanban.models import AtendimentoKanban
            atendimento = AtendimentoKanban.objects.get(id=ag.agendamento_id)
            assert atendimento.etapa == etapa_no_tenant
            assert atendimento.servico == servico_no_tenant
            assert atendimento.pago is False
            assert atendimento.data == data_hora.date()
            assert atendimento.horario_entrada == data_hora.time()

    def test_cria_pet_no_tenant_sincronizado_com_objeto_do_consumidor(
        self, tenant, consumidor_registrado, negocio_publico_kanban, servico_no_tenant,
        etapa_no_tenant, objeto_consumidor_pet,
    ):
        AgendamentoTenantService().criar(
            schema_name=tenant.schema_name,
            consumidor=consumidor_registrado,
            servico_ids=[servico_no_tenant.id],
            data_hora=timezone.now() + timedelta(hours=5),
            objeto_id=objeto_consumidor_pet.id,
        )
        with schema_context(tenant.schema_name):
            from apps_work.clientes.models import Pet
            pet = Pet.objects.get(nome='Rex')
            assert pet.especie == 'Cachorro'
            assert pet.porte == 'medio'  # normalizado pra minúsculo (choices do model)

    def test_sem_objeto_id_lanca_erro(
        self, tenant, consumidor_registrado, negocio_publico_kanban, servico_no_tenant, etapa_no_tenant,
    ):
        with pytest.raises(ValueError, match='pet ou veículo'):
            AgendamentoTenantService().criar(
                schema_name=tenant.schema_name,
                consumidor=consumidor_registrado,
                servico_ids=[servico_no_tenant.id],
                data_hora=timezone.now() + timedelta(hours=5),
            )

    def test_sem_etapa_configurada_lanca_erro(
        self, tenant, consumidor_registrado, negocio_publico_kanban, servico_no_tenant, objeto_consumidor_pet,
    ):
        with pytest.raises(ValueError, match='etapas'):
            AgendamentoTenantService().criar(
                schema_name=tenant.schema_name,
                consumidor=consumidor_registrado,
                servico_ids=[servico_no_tenant.id],
                data_hora=timezone.now() + timedelta(hours=5),
                objeto_id=objeto_consumidor_pet.id,
            )


# ---------------------------------------------------------------------------
# CrossTenantQueryService.listar_disponibilidade() -- negócio em modo Kanban
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestListarDisponibilidadeKanban:
    def test_retorna_datetimes_iso_disponiveis(self, tenant, negocio_publico_kanban):
        hoje = timezone.now().date() + timedelta(days=1)
        with schema_context(tenant.schema_name):
            from apps_work.empresa.models import EmpresaConfig, HorarioFuncionamento
            from apps_work.servicos.models import Servico
            EmpresaConfig.objects.create(pk=1, tipo_agenda='kanban')
            HorarioFuncionamento.objects.create(
                dia=hoje.weekday(), abertura='08:00', fechamento='11:00', ativo=True, capacidade=3,
            )
            servico = Servico.objects.create(nome='Banho', duracao=30, preco=Decimal('50.00'), ativo=True)

        slots = CrossTenantQueryService().listar_disponibilidade(
            tenant.schema_name, hoje, [servico.id],
        )
        assert len(slots) == 3
        from datetime import datetime as dt
        primeiro = dt.fromisoformat(slots[0])
        assert primeiro.date() == hoje
        assert primeiro.strftime('%H:%M') == '08:00'

    def test_nao_retorna_slot_ocupado(self, tenant, negocio_publico_kanban):
        hoje = timezone.now().date() + timedelta(days=1)
        with schema_context(tenant.schema_name):
            from apps_work.empresa.models import EmpresaConfig, HorarioFuncionamento
            from apps_work.servicos.models import Servico
            from apps_work.kanban.models import AtendimentoKanban, EtapaKanban
            from apps_work.clientes.models import Cliente, Pet
            EmpresaConfig.objects.create(pk=1, tipo_agenda='kanban')
            HorarioFuncionamento.objects.create(
                dia=hoje.weekday(), abertura='08:00', fechamento='11:00', ativo=True, capacidade=3,
            )
            servico = Servico.objects.create(nome='Banho', duracao=30, preco=Decimal('50.00'), ativo=True)
            etapa = EtapaKanban.objects.create(nome='Aguardando', ordem=0)
            cliente = Cliente.objects.create(nome='Fulano')
            pet = Pet.objects.create(cliente=cliente, tipo='pet', nome='Bob')
            AtendimentoKanban.objects.create(
                etapa=etapa, objeto=pet, servico=servico, data=hoje, horario_entrada='08:00',
            )

        slots = CrossTenantQueryService().listar_disponibilidade(
            tenant.schema_name, hoje, [servico.id],
        )
        assert len(slots) == 2
        assert all('08:00' not in s for s in slots)


# ---------------------------------------------------------------------------
# CancelarAgendamentoService.cancelar() -- negócio em modo Kanban
# ---------------------------------------------------------------------------

@pytest.mark.django_db(transaction=True)
class TestCancelarAgendamentoKanban:
    def test_cancelar_remove_atendimento_kanban(
        self, tenant, consumidor_registrado, negocio_publico_kanban, servico_no_tenant,
        etapa_no_tenant, objeto_consumidor_pet,
    ):
        ag = AgendamentoTenantService().criar(
            schema_name=tenant.schema_name,
            consumidor=consumidor_registrado,
            servico_ids=[servico_no_tenant.id],
            data_hora=timezone.now() + timedelta(hours=10),
            objeto_id=objeto_consumidor_pet.id,
        )
        atendimento_id = ag.agendamento_id

        CancelarAgendamentoService().cancelar(ag, consumidor_registrado)

        with schema_context(tenant.schema_name):
            from apps_work.kanban.models import AtendimentoKanban
            assert not AtendimentoKanban.objects.filter(id=atendimento_id).exists()

        ag.refresh_from_db()
        assert ag.status == 'cancelado'


# ---------------------------------------------------------------------------
# Savepoint na sincronizacao do cliente
# ---------------------------------------------------------------------------

def _erro_de_banco(*args, **kwargs):
    """Falha que aborta a transacao no Postgres.

    Diferente de um RuntimeError: este deixa a conexao em estado invalido, que e
    exatamente a condicao que o savepoint precisa conter.
    """
    from django.db import connection
    with connection.cursor() as cursor:
        cursor.execute('SELECT 1 FROM tabela_que_nao_existe')


@pytest.mark.django_db(transaction=True)
class TestFalhaNaSincronizacaoNaoDerrubaOAgendamento:
    def test_agendamento_persiste_apos_erro_de_banco_na_sincronizacao(
        self, tenant, consumidor_registrado, negocio_publico, servico_no_tenant
    ):
        """_sincronizar_cliente engole a excecao e roda dentro do atomic() de
        criar(). Sem savepoint, a transacao ficava abortada e o
        AgendamentoConsumidor seguinte nao chegava a ser gravado."""
        alvo = 'apps_work.notificacoes.models.Notificacao.objects.create'

        with patch(alvo, side_effect=_erro_de_banco):
            ag = AgendamentoTenantService().criar(
                schema_name=tenant.schema_name,
                consumidor=consumidor_registrado,
                servico_ids=[servico_no_tenant.id],
                data_hora=timezone.now() + timedelta(hours=2),
            )

        assert AgendamentoConsumidor.objects.filter(pk=ag.pk).exists()
