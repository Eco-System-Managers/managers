"""Comando popular_dev: banco local pronto para usar a API."""
import pytest
from django.contrib.auth.models import User
from django.core.management import CommandError, call_command
from django.db import connection
from django_tenants.utils import schema_context

from apps_work.billing.models import Assinatura, Plano
from tenants.models import Membro, Papel, Tenant


@pytest.mark.django_db
class TestPopularDev:
    def test_cria_plano_empresa_dono_e_conclui_onboarding(self, settings):
        settings.DEBUG = True
        call_command('popular_dev', verbosity=0)

        assert Plano.objects.filter(nome=settings.PLANO_PADRAO, ativo=True).exists()
        user = User.objects.get(username='dono@demo.com')
        membro = Membro.objects.get(user=user)
        assert membro.papel == Papel.PROPRIETARIO
        # Com o plano existindo, o cadastro já nasce com o trial.
        assert Assinatura.objects.filter(tenant=membro.tenant).exists()

        from apps_work.empresa.models import EmpresaConfig
        from apps_work.usuarios.models import Colaborador
        with schema_context(membro.tenant.schema_name):
            assert EmpresaConfig.objects.get(pk=1).onboarding_concluido is True
            assert Colaborador.objects.filter(user=user).exists()
        connection.set_schema_to_public()

    def test_rodar_de_novo_nao_duplica(self, settings):
        settings.DEBUG = True
        call_command('popular_dev', verbosity=0)
        call_command('popular_dev', verbosity=0)
        assert Tenant.objects.filter(nome='Barbearia Demo').count() == 1

    def test_nao_roda_sem_debug(self, settings):
        settings.DEBUG = False
        with pytest.raises(CommandError):
            call_command('popular_dev', verbosity=0)

    def test_nicho_kanban_nasce_com_quadro_e_etapas(self, settings):
        settings.DEBUG = True
        call_command('popular_dev', '--nicho', 'lava_rapido', verbosity=0)

        user = User.objects.get(username='dono.lava@demo.com')
        membro = Membro.objects.get(user=user)
        assert membro.tenant.nome == 'Lava Rápido Demo'

        from apps_work.empresa.models import EmpresaConfig
        from apps_work.kanban.models import EtapaKanban
        with schema_context(membro.tenant.schema_name):
            config = EmpresaConfig.objects.get(pk=1)
            assert config.nicho == 'lava_rapido'
            assert config.tipo_agenda == 'kanban'
            assert config.tipo_objeto == 'veiculo'
            assert EtapaKanban.objects.count() == 3
        connection.set_schema_to_public()
