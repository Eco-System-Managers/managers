from importlib import import_module
from types import SimpleNamespace

import pytest
from django.apps import apps as registro_de_apps
from unittest.mock import patch

from apps_serv.consumidores.models import VinculoConsumidor
from apps_serv.consumidores.services import RegistroConsumidorService, SincronizarClienteService
from apps_serv.identidade import cliente_do_consumidor
from apps_serv.vitrine.services import VincularNegocioService
from apps_work.clientes.models import Cliente


@pytest.fixture
def consumidor(db):
    return RegistroConsumidorService().registrar(
        nome='Carlos Cliente',
        email='carlos@sm.com',
        senha='SenhaForte123!',
    )


@pytest.mark.django_db
class TestClienteDoConsumidor:
    def test_acha_pelo_id_do_consumidor(self, patch_tenant_middleware, consumidor, tenant):
        cliente = Cliente.objects.create(
            nome='Carlos', email='carlos@sm.com', telefone='11999990000',
            consumidor_id=consumidor.id,
        )
        assert cliente_do_consumidor(consumidor) == cliente

    def test_acha_pelo_email_quando_o_id_ainda_nao_foi_gravado(
        self, patch_tenant_middleware, consumidor, tenant,
    ):
        """Cadastro anterior a coluna existir, que o backfill nao alcancou."""
        cliente = Cliente.objects.create(
            nome='Carlos', email='carlos@sm.com', telefone='11999990000',
        )
        assert cliente_do_consumidor(consumidor) == cliente

    def test_grava_o_id_ao_achar_pelo_email(self, patch_tenant_middleware, consumidor, tenant):
        """A cura no acesso e o que faz o codigo funcionar antes e depois do
        backfill: um tenant que a migration nao alcancou se acerta sozinho."""
        cliente = Cliente.objects.create(
            nome='Carlos', email='carlos@sm.com', telefone='11999990000',
        )

        cliente_do_consumidor(consumidor)

        cliente.refresh_from_db()
        assert cliente.consumidor_id == consumidor.id

    def test_prefere_o_id_quando_o_email_aponta_para_outro_cadastro(
        self, patch_tenant_middleware, consumidor, tenant,
    ):
        """O e-mail e so reserva: existindo o id, e ele que manda."""
        Cliente.objects.create(nome='Homonimo', email='carlos@sm.com', telefone='11888880000')
        certo = Cliente.objects.create(
            nome='Carlos', email='outro@sm.com', telefone='11999990000',
            consumidor_id=consumidor.id,
        )
        assert cliente_do_consumidor(consumidor) == certo

    def test_nao_rouba_cadastro_ja_ligado_a_outro_consumidor(
        self, patch_tenant_middleware, consumidor, tenant, db,
    ):
        outro = RegistroConsumidorService().registrar(
            nome='Outro', email='outro-dono@sm.com', senha='SenhaForte123!',
        )
        Cliente.objects.create(
            nome='Ja ligado', email='carlos@sm.com', telefone='11777770000',
            consumidor_id=outro.id,
        )
        assert cliente_do_consumidor(consumidor) is None

    def test_devolve_none_quando_o_negocio_nao_conhece_a_pessoa(
        self, patch_tenant_middleware, consumidor, tenant,
    ):
        assert cliente_do_consumidor(consumidor) is None

    def test_falha_ao_gravar_o_id_nao_derruba_a_operacao(
        self, patch_tenant_middleware, consumidor, tenant,
    ):
        """O agendamento nao pode quebrar por causa da ligacao."""
        cliente = Cliente.objects.create(
            nome='Carlos', email='carlos@sm.com', telefone='11999990000',
        )
        with patch.object(Cliente, 'save', side_effect=RuntimeError('boom')):
            assert cliente_do_consumidor(consumidor) == cliente


@pytest.mark.django_db
class TestIdentidadeSobreviveATrocaDeEmail:
    """O motivo de o item existir: a ligacao deixa de depender de um dado que a
    pessoa pode querer trocar."""

    def test_vinculo_continua_apos_o_consumidor_trocar_de_email(
        self, patch_tenant_middleware, consumidor, tenant,
    ):
        VincularNegocioService().vincular(tenant.schema_name, consumidor)
        cliente = Cliente.objects.get(consumidor_id=consumidor.id)

        consumidor.email = 'carlos.novo@sm.com'
        consumidor.save(update_fields=['email'])

        assert cliente_do_consumidor(consumidor) == cliente

    def test_sincronizacao_do_perfil_sobrevive_a_troca(
        self, patch_tenant_middleware, consumidor, tenant,
    ):
        VincularNegocioService().vincular(tenant.schema_name, consumidor)

        consumidor.email = 'carlos.novo@sm.com'
        consumidor.nome = 'Carlos Renomeado'
        consumidor.save(update_fields=['email', 'nome'])

        assert SincronizarClienteService().sincronizar(consumidor) == 1

        cliente = Cliente.objects.get(consumidor_id=consumidor.id)
        assert cliente.nome == 'Carlos Renomeado'


@pytest.mark.django_db
class TestCriacaoGravaAIdentidade:
    def test_vincular_cria_cliente_ja_ligado(self, patch_tenant_middleware, consumidor, tenant):
        VincularNegocioService().vincular(tenant.schema_name, consumidor)
        cliente = Cliente.objects.get(email=consumidor.email)
        assert cliente.consumidor_id == consumidor.id

    def test_revinculo_reaproveita_o_mesmo_cadastro(
        self, patch_tenant_middleware, consumidor, tenant,
    ):
        servico = VincularNegocioService()
        servico.vincular(tenant.schema_name, consumidor)
        servico.desvincular(tenant.schema_name, consumidor)
        servico.vincular(tenant.schema_name, consumidor)

        assert Cliente.objects.filter(consumidor_id=consumidor.id).count() == 1
        assert VinculoConsumidor.objects.filter(consumidor=consumidor, ativo=True).count() == 1


# ---------------------------------------------------------------------------
# Backfill da migration
# ---------------------------------------------------------------------------

_MIGRATION = import_module('apps_work.clientes.migrations.0011_cliente_consumidor_id')


def _rodar_backfill(schema_name):
    """Chama a funcao da migration direto.

    A migration em si roda no setup do banco de teste, quando nao ha dado
    nenhum — entao o backfill nunca seria exercitado de verdade por ali.
    """
    editor = SimpleNamespace(connection=SimpleNamespace(schema_name=schema_name))
    _MIGRATION.ligar_pelo_email(registro_de_apps, editor)


@pytest.mark.django_db
class TestBackfillDaMigration:
    def _cliente(self, email, origem=Cliente.ORIGEM_SERVICEMANAGE, nome='Carlos'):
        return Cliente.objects.create(
            nome=nome, email=email, telefone='11999990000', origem=origem,
        )

    def test_liga_cadastro_vindo_do_app(self, patch_tenant_middleware, consumidor, tenant):
        cliente = self._cliente(consumidor.email)

        _rodar_backfill(tenant.schema_name)

        cliente.refresh_from_db()
        assert cliente.consumidor_id == consumidor.id

    def test_nao_toca_cadastro_feito_pelo_negocio(
        self, patch_tenant_middleware, consumidor, tenant,
    ):
        """Homonimo cadastrado na mao nao vira o consumidor por coincidencia
        de e-mail."""
        cliente = self._cliente(consumidor.email, origem=Cliente.ORIGEM_MANUAL)

        _rodar_backfill(tenant.schema_name)

        cliente.refresh_from_db()
        assert cliente.consumidor_id is None

    def test_ignora_cadastro_sem_email(self, patch_tenant_middleware, consumidor, tenant):
        cliente = self._cliente('')

        _rodar_backfill(tenant.schema_name)

        cliente.refresh_from_db()
        assert cliente.consumidor_id is None

    def test_liga_apenas_o_primeiro_quando_ha_dois_com_o_mesmo_email(
        self, patch_tenant_middleware, consumidor, tenant,
    ):
        """`email` nao e unico no Cliente. Ligar os dois violaria a unicidade de
        consumidor_id e abortaria a migration do tenant inteiro."""
        primeiro = self._cliente(consumidor.email, nome='Primeiro')
        segundo = self._cliente(consumidor.email, nome='Segundo')

        _rodar_backfill(tenant.schema_name)

        primeiro.refresh_from_db()
        segundo.refresh_from_db()
        assert primeiro.consumidor_id == consumidor.id
        assert segundo.consumidor_id is None

    def test_nao_faz_nada_no_schema_publico(self, patch_tenant_middleware, consumidor, tenant):
        """Apps de tenant tambem sao criadas no publico, onde nao ha cliente de
        negocio para ligar."""
        cliente = self._cliente(consumidor.email)

        _rodar_backfill('public')

        cliente.refresh_from_db()
        assert cliente.consumidor_id is None

    def test_e_idempotente(self, patch_tenant_middleware, consumidor, tenant):
        cliente = self._cliente(consumidor.email)

        _rodar_backfill(tenant.schema_name)
        _rodar_backfill(tenant.schema_name)

        cliente.refresh_from_db()
        assert cliente.consumidor_id == consumidor.id
