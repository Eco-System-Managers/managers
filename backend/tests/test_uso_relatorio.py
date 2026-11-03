"""O relatório de uso (apps_work/uso/relatorio.py e o comando relatorio_uso)."""
from datetime import timedelta
from io import StringIO

import pytest
from django.core.management import call_command
from django.db import connection
from django.utils import timezone

from apps_work.clientes.models import Cliente
from apps_work.empresa.models import EmpresaConfig
from apps_work.servicos.models import Servico
from apps_work.uso.models import EventoDeUso
from apps_work.uso.relatorio import montar


def _evento(tenant, evento, status=200, user_id=1, dias_atras=0, **extra):
    connection.set_schema_to_public()
    criado = EventoDeUso.objects.create(
        schema_name=tenant.schema_name, user_id=user_id, evento=evento,
        metodo='POST', status=status, duracao_ms=extra.pop('duracao_ms', 50), **extra,
    )
    if dias_atras:
        EventoDeUso.objects.filter(pk=criado.pk).update(criado_em=timezone.now() - timedelta(days=dias_atras))
    connection.set_tenant(tenant)
    return criado


@pytest.fixture
def negocio(tenant):
    EmpresaConfig.objects.create(pk=1, nichos=['cabeleireiro'], onboarding_concluido=True)
    Servico.objects.create(nome='Corte', nicho='cabeleireiro', duracao=30, preco='50.00')
    Cliente.objects.create(nome='Ana', telefone='11999999999')
    return tenant


@pytest.mark.django_db
class TestMontar:
    def test_conta_pessoas_acoes_e_erros_do_periodo(self, negocio):
        _evento(negocio, 'app.aberto', user_id=1)
        _evento(negocio, 'agendamento.criar', status=201, user_id=1)
        _evento(negocio, 'agendamento.criar', status=201, user_id=2)
        _evento(negocio, 'agendamento.criar', status=400, codigo='horario_conflito', user_id=2)
        _evento(negocio, 'agendamento.criar', status=201, dias_atras=30)

        r = montar(dias=7)

        [dia] = r.por_dia
        assert dia['pessoas'] == 2
        assert dia['acoes'] == 2
        assert dia['erros'] == 1
        assert r.acoes_mais_usadas[0]['evento'] == 'agendamento.criar'
        assert r.acoes_mais_usadas[0]['total'] == 2
        assert [(e['codigo'], e['total']) for e in r.erros_de_regra] == [('horario_conflito', 1)]

    def test_erro_do_servidor_e_lentidao(self, negocio):
        _evento(negocio, 'agendamento-cobrar', status=500, duracao_ms=3000)
        _evento(negocio, 'servico.criar', status=201, duracao_ms=40)

        r = montar(dias=7)

        assert [e.evento for e in r.erros_do_servidor] == ['agendamento-cobrar']
        assert r.mais_lentas[0]['evento'] == 'agendamento-cobrar'

    def test_negocio_com_funil_e_ultimo_uso_de_sempre(self, negocio):
        _evento(negocio, 'servico.criar', status=201, dias_atras=20)

        r = montar(dias=7)

        [n] = r.negocios
        assert n.schema_name == negocio.schema_name
        assert n.acoes == 0  # nada no período
        assert n.ultimo_uso is not None  # mas usou um dia
        assert n.funil.onboarding is True
        assert n.funil.servicos == 1
        assert n.funil.clientes == 1
        assert n.funil.atendimentos == 0


@pytest.mark.django_db
def test_comando_imprime_as_secoes(negocio):
    _evento(negocio, 'agendamento.criar', status=201)
    saida = StringIO()

    call_command('relatorio_uso', '--dias', '3', stdout=saida)

    texto = saida.getvalue()
    assert 'Por dia' in texto
    assert 'Empresa Teste (test_empresa)' in texto
    assert 'agendamento.criar' in texto
    assert '1 serviços' in texto
