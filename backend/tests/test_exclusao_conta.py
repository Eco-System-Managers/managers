"""Excluir a conta pelo app: o pedido trava na hora, entrar de novo desiste e,
vencido o prazo, o dono leva o negócio inteiro e a equipe só o login."""
from datetime import datetime, timedelta

import pytest
from django.contrib.auth.models import User
from django.db import connection
from django.utils import timezone
from django_tenants.utils import schema_context
from rest_framework.test import APIClient

from apps_serv.consumidores.models import AgendamentoConsumidor, Consumidor
from apps_serv.vitrine.models import NegocioPublico
from apps_work.agenda.models import Agendamento
from apps_work.autenticacao.models import ExclusaoConta
from apps_work.autenticacao.services import ExclusaoContaService
from apps_work.clientes.models import Cliente
from apps_work.usuarios.models import Colaborador
from tenants.models import Membro, Tenant

URL = '/api/v1/colaboradores/me/excluir/'
LOGIN = '/api/v1/auth/login/'


def _client(user=None):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    if user is not None:
        client.force_authenticate(user=user)
    return client


@pytest.fixture
def dono(patch_tenant_middleware, proprietario):
    Colaborador.objects.create(user=proprietario, nome='Dono')
    return proprietario


@pytest.fixture
def leo(patch_tenant_middleware, tenant):
    user = User.objects.create_user(username='leo@x.com', email='leo@x.com', password='SenhaForte123!', first_name='Léo')
    Membro.objects.create(user=user, tenant=tenant, papel='colaborador')
    Colaborador.objects.create(user=user, tipo='parceiro')
    return user


def _entrar(email, senha):
    return _client().post(LOGIN, {'email': email, 'senha': senha}, format='json')


@pytest.mark.django_db
class TestPedido:
    def test_senha_errada_nao_pede(self, dono):
        resposta = _client(dono).post(URL, {'senha': 'errada'}, format='json')

        assert resposta.status_code == 400
        assert resposta.json()['code'] == 'senha_incorreta'
        assert not ExclusaoConta.objects.exists()

    def test_dono_pede_o_negocio_inteiro_e_a_vitrine_sai(self, dono, tenant):
        NegocioPublico.objects.create(
            schema_name=tenant.schema_name, nome='Empresa', nichos=['barbearia'],
            latitude='-23.5', longitude='-46.6', ativo=True,
        )

        resposta = _client(dono).post(URL, {'senha': 'senha123'}, format='json')

        assert resposta.status_code == 202
        assert resposta.json()['apaga_negocio'] is True
        exclusao = ExclusaoConta.objects.get(user=dono)
        assert exclusao.excluir_em > timezone.now() + timedelta(days=29)
        assert NegocioPublico.objects.get(schema_name=tenant.schema_name).ativo is False

    def test_equipe_pede_so_o_login(self, dono, leo):
        resposta = _client(leo).post(URL, {'senha': 'SenhaForte123!'}, format='json')

        assert resposta.status_code == 202
        assert resposta.json()['apaga_negocio'] is False

    def test_com_o_negocio_em_exclusao_a_equipe_nao_entra(self, dono, leo):
        _client(dono).post(URL, {'senha': 'senha123'}, format='json')

        resposta = _entrar('leo@x.com', 'SenhaForte123!')

        assert resposta.status_code == 403
        assert resposta.json()['code'] == 'negocio_em_exclusao'

    def test_entrar_de_novo_desiste(self, dono, leo):
        _client(leo).post(URL, {'senha': 'SenhaForte123!'}, format='json')

        resposta = _entrar('leo@x.com', 'SenhaForte123!')

        assert resposta.status_code == 200
        assert not ExclusaoConta.objects.filter(user=leo).exists()

    def test_o_dono_entrar_de_novo_devolve_o_acesso_da_equipe(self, dono, leo):
        _client(dono).post(URL, {'senha': 'senha123'}, format='json')

        assert _entrar('teste@email.com', 'senha123').status_code == 200
        assert _entrar('leo@x.com', 'SenhaForte123!').status_code == 200


@pytest.mark.django_db
class TestExclusaoVencida:
    def _vencer(self):
        ExclusaoConta.objects.update(excluir_em=timezone.now() - timedelta(minutes=1))

    def test_no_prazo_nada_some(self, dono, leo):
        _client(leo).post(URL, {'senha': 'SenhaForte123!'}, format='json')

        assert ExclusaoContaService().excluir_vencidas() == 0
        assert User.objects.filter(pk=leo.pk).exists()

    def test_da_equipe_some_o_login_e_fica_o_nome_no_historico(self, dono, leo):
        colaborador = Colaborador.objects.get(user=leo)
        cliente = Cliente.objects.create(nome='Ana', telefone='11999999999')
        agendamento = Agendamento.objects.create(
            cliente=cliente, colaborador=colaborador, data_hora=timezone.now() - timedelta(days=3),
        )
        _client(leo).post(URL, {'senha': 'SenhaForte123!'}, format='json')
        self._vencer()

        assert ExclusaoContaService().excluir_vencidas() == 1

        assert not User.objects.filter(pk=leo.pk).exists()
        assert not Membro.objects.filter(user_id=leo.pk).exists()
        colaborador.refresh_from_db()
        assert colaborador.user is None
        assert colaborador.nome == 'Léo'
        assert colaborador.ativo is False
        agendamento.refresh_from_db()
        assert agendamento.colaborador_id == colaborador.pk

    def test_do_dono_some_o_negocio_inteiro(self, dono, leo, tenant):
        schema = tenant.schema_name
        consumidor = Consumidor.objects.create(nome='Bia', email='bia@x.com')
        marcado = AgendamentoConsumidor.objects.create(
            consumidor=consumidor, schema_name=schema, agendamento_id=1, negocio_nome='Empresa',
            data_hora=timezone.now() + timedelta(days=2), duracao_total=30, valor_total='50.00',
        )
        _client(dono).post(URL, {'senha': 'senha123'}, format='json')
        self._vencer()

        connection.set_schema_to_public()
        assert ExclusaoContaService().excluir_vencidas() == 1

        assert not Tenant.objects.filter(schema_name=schema).exists()
        assert not User.objects.filter(pk__in=[dono.pk, leo.pk]).exists()
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1 FROM information_schema.schemata WHERE schema_name = %s', [schema])
            assert cursor.fetchone() is None
        marcado.refresh_from_db()
        assert marcado.status == 'cancelado'
        assert not ExclusaoConta.objects.exists()
