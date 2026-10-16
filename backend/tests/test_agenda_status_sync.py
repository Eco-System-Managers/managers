import pytest
from datetime import timedelta

from django.utils import timezone
from rest_framework.test import APIClient

from apps_serv.consumidores.models import AgendamentoConsumidor
from apps_serv.consumidores.services import RegistroConsumidorService
from apps_work.agenda.models import Agendamento
from apps_work.clientes.models import Cliente


@pytest.fixture
def client_autenticado(patch_tenant_middleware, usuario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=usuario)
    return client


@pytest.fixture
def consumidor(db):
    return RegistroConsumidorService().registrar(
        nome='Carlos Cliente', email='carlos@sm.com', senha='SenhaForte123!',
    )


@pytest.fixture
def agendamento(patch_tenant_middleware):
    cliente = Cliente.objects.create(nome='Carlos Cliente', email='carlos@sm.com')
    return Agendamento.objects.create(
        cliente=cliente,
        data_hora=timezone.now() + timedelta(days=3),
        status='agendado',
    )


def _espelho(consumidor, tenant, agendamento, origem='agenda'):
    return AgendamentoConsumidor.objects.create(
        consumidor=consumidor,
        schema_name=tenant.schema_name,
        agendamento_id=agendamento.pk,
        origem=origem,
        negocio_nome='Empresa Teste',
        data_hora=agendamento.data_hora,
        duracao_total=30,
        valor_total='50.00',
        status='agendado',
    )


@pytest.mark.django_db
class TestStatusEspelhadoNoConsumidor:
    def test_faltou_chega_no_app(self, client_autenticado, consumidor, tenant, agendamento):
        espelho = _espelho(consumidor, tenant, agendamento)

        client_autenticado.patch(f'/api/agendamentos/{agendamento.pk}/', {'status': 'faltou'}, format='json')

        espelho.refresh_from_db()
        assert espelho.status == 'faltou'

    def test_concluido_chega_no_app(self, client_autenticado, consumidor, tenant, agendamento):
        espelho = _espelho(consumidor, tenant, agendamento)

        client_autenticado.patch(f'/api/agendamentos/{agendamento.pk}/', {'status': 'concluido'}, format='json')

        espelho.refresh_from_db()
        assert espelho.status == 'concluido'

    def test_voltar_para_ativo_chega_no_app(self, client_autenticado, consumidor, tenant, agendamento):
        """O caminho de volta do beco sem saída também precisa espelhar."""
        agendamento.status = 'faltou'
        agendamento.save(update_fields=['status'])
        espelho = _espelho(consumidor, tenant, agendamento)
        espelho.status = 'faltou'
        espelho.save(update_fields=['status'])

        client_autenticado.patch(f'/api/agendamentos/{agendamento.pk}/', {'status': 'confirmado'}, format='json')

        espelho.refresh_from_db()
        assert espelho.status == 'confirmado'

    def test_salvar_sem_mudar_status_nao_mexe_no_espelho(self, client_autenticado, consumidor, tenant, agendamento):
        espelho = _espelho(consumidor, tenant, agendamento)
        espelho.status = 'confirmado'
        espelho.save(update_fields=['status'])

        client_autenticado.patch(
            f'/api/agendamentos/{agendamento.pk}/', {'observacoes': 'chegou cedo'}, format='json'
        )

        espelho.refresh_from_db()
        assert espelho.status == 'confirmado'

    def test_agendamento_de_esteira_nao_e_espelhado(self, client_autenticado, consumidor, tenant, agendamento):
        """Esteira tem status lido ao vivo da coluna — não pode ser sobrescrito."""
        espelho = _espelho(consumidor, tenant, agendamento, origem='kanban')

        client_autenticado.patch(f'/api/agendamentos/{agendamento.pk}/', {'status': 'faltou'}, format='json')

        espelho.refresh_from_db()
        assert espelho.status == 'agendado'

    def test_agendamento_do_balcao_nao_quebra(self, client_autenticado, agendamento):
        """Sem contraparte no público, o handler simplesmente não acha nada."""
        response = client_autenticado.patch(
            f'/api/agendamentos/{agendamento.pk}/', {'status': 'faltou'}, format='json'
        )
        assert response.status_code == 200

    def test_espelho_de_outro_negocio_nao_e_afetado(self, client_autenticado, consumidor, tenant, agendamento):
        espelho = _espelho(consumidor, tenant, agendamento)
        outro = AgendamentoConsumidor.objects.create(
            consumidor=consumidor, schema_name='outro_negocio',
            agendamento_id=agendamento.pk, origem='agenda',
            negocio_nome='Outro', data_hora=agendamento.data_hora,
            duracao_total=30, valor_total='50.00', status='agendado',
        )

        client_autenticado.patch(f'/api/agendamentos/{agendamento.pk}/', {'status': 'faltou'}, format='json')

        espelho.refresh_from_db(); outro.refresh_from_db()
        assert outro.status == 'agendado'

    def test_cobrar_espelha_conclusao(self, client_autenticado, consumidor, tenant, agendamento):
        """Cobrar conclui o agendamento sem passar pelo PATCH de status."""
        from apps_work.agenda.models import AgendamentoServico
        from apps_work.servicos.models import Servico

        servico = Servico.objects.create(nome='Corte', duracao=30, preco='50.00')
        AgendamentoServico.objects.create(agendamento=agendamento, servico=servico, preco_cobrado='50.00')
        espelho = _espelho(consumidor, tenant, agendamento)

        client_autenticado.post(
            f'/api/agendamentos/{agendamento.pk}/cobrar/',
            {'desconto': 0, 'pagamentos': [{'forma': 'pix', 'valor': '50.00'}]},
            format='json',
        )

        espelho.refresh_from_db()
        assert espelho.status == 'concluido'
