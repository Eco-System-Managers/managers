import pytest
from unittest.mock import patch

from apps_serv.consumidores.models import VinculoConsumidor
from apps_serv.consumidores.services import RegistroConsumidorService
from apps_serv.vitrine.services import VincularNegocioService
from apps_work.clientes.models import Cliente, OrigemCliente
from apps_work.notificacoes.models import Notificacao


@pytest.fixture
def consumidor(db):
    return RegistroConsumidorService().registrar(
        nome='Carlos Cliente',
        email='carlos@sm.com',
        senha='SenhaForte123!',
    )


def _notificacoes_vinculo():
    return Notificacao.objects.filter(tipo='cliente_vinculado').count()


@pytest.mark.django_db
class TestNotificacaoSoNaTransicao:
    def test_primeiro_vinculo_notifica(self, patch_tenant_middleware, consumidor, tenant):
        VincularNegocioService().garantir_vinculo(tenant.schema_name, consumidor)
        assert _notificacoes_vinculo() == 1

    def test_agendamento_de_quem_ja_e_cliente_nao_notifica(self, patch_tenant_middleware, consumidor, tenant):
        """garantir_vinculo roda a cada agendamento — sem a checagem de
        transição o dono recebia o aviso toda vez."""
        servico = VincularNegocioService()
        servico.garantir_vinculo(tenant.schema_name, consumidor)
        servico.garantir_vinculo(tenant.schema_name, consumidor)
        servico.garantir_vinculo(tenant.schema_name, consumidor)
        assert _notificacoes_vinculo() == 1

    def test_revinculo_apos_desvincular_notifica_de_novo(self, patch_tenant_middleware, consumidor, tenant):
        servico = VincularNegocioService()
        servico.garantir_vinculo(tenant.schema_name, consumidor)
        servico.desvincular(tenant.schema_name, consumidor)
        servico.garantir_vinculo(tenant.schema_name, consumidor)
        assert _notificacoes_vinculo() == 2

    def test_vinculo_manual_notifica(self, patch_tenant_middleware, consumidor, tenant):
        VincularNegocioService().vincular(tenant.schema_name, consumidor)
        assert _notificacoes_vinculo() == 1

    def test_desvincular_notifica(self, patch_tenant_middleware, consumidor, tenant):
        servico = VincularNegocioService()
        servico.garantir_vinculo(tenant.schema_name, consumidor)
        servico.desvincular(tenant.schema_name, consumidor)
        assert Notificacao.objects.filter(tipo='cliente_desvinculado').count() == 1

    def test_agendamento_repetido_ainda_sincroniza_o_perfil(self, patch_tenant_middleware, consumidor, tenant):
        """Não notificar não pode desligar a propagação do cadastro único."""
        servico = VincularNegocioService()
        servico.garantir_vinculo(tenant.schema_name, consumidor)

        consumidor.nome = 'Carlos Nome Novo'
        consumidor.telefone = '11955554444'
        consumidor.save()
        servico.garantir_vinculo(tenant.schema_name, consumidor)

        cliente = Cliente.objects.get(email=consumidor.email)
        assert cliente.nome == 'Carlos Nome Novo'


@pytest.mark.django_db
class TestOrigemNoVinculo:
    def test_cliente_criado_pelo_vinculo_nasce_servicemanage(self, patch_tenant_middleware, consumidor, tenant):
        VincularNegocioService().garantir_vinculo(tenant.schema_name, consumidor)
        assert Cliente.objects.get(email=consumidor.email).origem == OrigemCliente.SERVICEMANAGE

    def test_cadastro_manual_vira_servicemanage_ao_vincular(self, patch_tenant_middleware, consumidor, tenant):
        """O negócio já tinha o cliente na mão; ao vincular, a posse do cadastro
        passa pro consumidor — senão remover pelo painel apagaria a linha e
        deixaria o vínculo ativo no público."""
        Cliente.objects.create(
            nome='Carlos (digitado errado)', email=consumidor.email,
            telefone='1100000000', origem=OrigemCliente.MANUAL,
        )

        VincularNegocioService().garantir_vinculo(tenant.schema_name, consumidor)

        assert Cliente.objects.get(email=consumidor.email).origem == OrigemCliente.SERVICEMANAGE

    def test_cadastro_manual_de_quem_nao_vinculou_continua_manual(self, patch_tenant_middleware, consumidor, tenant):
        outro = Cliente.objects.create(
            nome='Cliente da Loja', email='outro@loja.com', origem=OrigemCliente.MANUAL,
        )
        VincularNegocioService().garantir_vinculo(tenant.schema_name, consumidor)
        outro.refresh_from_db()
        assert outro.origem == OrigemCliente.MANUAL


@pytest.mark.django_db
class TestFalhaNaSincronizacaoNaoQuebraOVinculo:
    def test_vinculo_persiste_mesmo_com_erro_na_sincronizacao(self, patch_tenant_middleware, consumidor, tenant):
        with patch('apps_work.clientes.models.Cliente.objects.filter', side_effect=RuntimeError('boom')):
            VincularNegocioService().garantir_vinculo(tenant.schema_name, consumidor)

        assert VinculoConsumidor.objects.filter(
            consumidor=consumidor, schema_name=tenant.schema_name, ativo=True
        ).exists()

    def test_falha_na_sincronizacao_e_registrada(self, patch_tenant_middleware, consumidor, tenant):
        """Antes era `except: pass` — a dessincronia acontecia sem deixar rastro."""
        with patch('apps_work.clientes.models.Cliente.objects.filter', side_effect=RuntimeError('boom')):
            with patch('apps_serv.vitrine.services.logger') as log:
                VincularNegocioService().garantir_vinculo(tenant.schema_name, consumidor)

        assert log.warning.called
