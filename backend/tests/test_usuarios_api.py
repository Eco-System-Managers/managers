import pytest
from unittest.mock import patch
from datetime import timedelta
from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APIClient

from apps_work.usuarios.models import Colaborador, ConviteColaborador
from apps_work.usuarios.services import AceitarConviteService, ConviteService


@pytest.fixture
def client_autenticado(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def colaborador(patch_tenant_middleware, usuario):
    return Colaborador.objects.create(user=usuario, funcao='Cabeleireiro', role='colaborador')


@pytest.fixture
def convite_valido(patch_tenant_middleware):
    return ConviteColaborador.objects.create(
        nome='Ana Lima',
        email='ana@email.com',
        expira_em=timezone.now() + timedelta(days=2),
    )


@pytest.fixture
def convite_expirado(patch_tenant_middleware):
    return ConviteColaborador.objects.create(
        nome='Carlos',
        email='carlos@email.com',
        expira_em=timezone.now() - timedelta(hours=1),
    )


@pytest.fixture
def convite_aceito(patch_tenant_middleware):
    return ConviteColaborador.objects.create(
        nome='Pedro',
        email='pedro@email.com',
        expira_em=timezone.now() + timedelta(days=2),
        aceito=True,
    )


# --- ConviteService ---

@pytest.mark.django_db
class TestConviteService:
    @patch('apps_work.usuarios.services.send_mail')
    def test_criar_e_enviar_cria_convite_com_dados_corretos(self, mock_mail, patch_tenant_middleware):
        convite = ConviteService().criar_e_enviar(
            nome='Ana Lima', email='ana@email.com', tenant_nome='Empresa Teste'
        )
        assert convite.pk is not None
        assert convite.email == 'ana@email.com'
        assert convite.nome == 'Ana Lima'
        assert convite.expira_em > timezone.now()

    @patch('apps_work.usuarios.services.send_mail')
    def test_criar_e_enviar_bloqueia_agenda_kanban(self, mock_mail, patch_tenant_middleware):
        from apps_work.empresa.models import EmpresaConfig
        EmpresaConfig.objects.create(pk=1, tipo_agenda='kanban')
        with pytest.raises(ValueError, match='Empresas com agenda por esteira'):
            ConviteService().criar_e_enviar(
                nome='Ana', email='ana@email.com', tenant_nome='Empresa'
            )

    @patch('apps_work.usuarios.services.send_mail')
    def test_enviar_email_usa_link_com_token(self, mock_mail, patch_tenant_middleware):
        convite = ConviteService().criar_e_enviar(
            nome='Ana Lima', email='ana@email.com', tenant_nome='Empresa Teste'
        )
        _, kwargs = mock_mail.call_args
        assert str(convite.token) in kwargs['message']

    def test_criar_convite_com_email_ja_vinculado_a_conta_lanca_excecao(self, patch_tenant_middleware):
        User.objects.create_user(username='ana@email.com', email='ana@email.com', password='senha123')
        with pytest.raises(ValueError, match='Este e-mail já está vinculado a uma conta.'):
            ConviteService().criar_e_enviar(
                nome='Ana Lima', email='ana@email.com', tenant_nome='Empresa'
            )

    def test_criar_convite_com_email_ja_pendente_lanca_excecao(self, convite_valido, patch_tenant_middleware):
        with pytest.raises(ValueError, match='Já existe um convite pendente para este e-mail.'):
            ConviteService().criar_e_enviar(
                nome='Ana Lima', email=convite_valido.email, tenant_nome='Empresa'
            )

    @patch('apps_work.usuarios.services.send_mail')
    def test_criar_convite_permite_apos_expiracao(self, mock_mail, convite_expirado, patch_tenant_middleware):
        convite = ConviteService().criar_e_enviar(
            nome='Carlos', email=convite_expirado.email, tenant_nome='Empresa'
        )
        assert convite.pk is not None

    @patch('apps_work.usuarios.services.send_mail')
    def test_criar_convite_permite_apos_aceito(self, mock_mail, convite_aceito, patch_tenant_middleware):
        convite = ConviteService().criar_e_enviar(
            nome='Pedro', email=convite_aceito.email, tenant_nome='Empresa'
        )
        assert convite.pk is not None


# --- AceitarConviteService (validações isoladas) ---

@pytest.mark.django_db
class TestAceitarConviteService:
    def test_validar_senha_fraca_lanca_excecao(self, patch_tenant_middleware):
        with pytest.raises(ValueError):
            AceitarConviteService()._validar_senha('123')

    def test_validar_senha_forte_nao_lanca_excecao(self, patch_tenant_middleware):
        AceitarConviteService()._validar_senha('SenhaForte@2024!')

    def test_validar_convite_expirado_lanca_excecao(self, convite_expirado):
        with pytest.raises(ValueError, match='expirou'):
            AceitarConviteService()._validar_expiracao(convite_expirado)

    def test_validar_convite_valido_nao_lanca_excecao(self, convite_valido):
        AceitarConviteService()._validar_expiracao(convite_valido)


# --- ColaboradorViewSet ---

@pytest.fixture
def outro_usuario(patch_tenant_middleware):
    from django.contrib.auth.models import User
    return User.objects.create_user(
        username='colab@email.com',
        email='colab@email.com',
        password='SenhaForte123!',
        first_name='Colab',
    )


@pytest.fixture
def colaborador_outro(patch_tenant_middleware, outro_usuario):
    return Colaborador.objects.create(user=outro_usuario, funcao='Barbeiro', role='colaborador')


@pytest.mark.django_db
class TestColaboradorAPI:
    def test_listar_colaboradores_retorna_200(self, client_autenticado, colaborador):
        response = client_autenticado.get('/api/colaboradores/')
        assert response.status_code == 200
        assert len(response.data) == 1

    def test_buscar_por_nome_filtra_colaboradores(self, client_autenticado, colaborador):
        response = client_autenticado.get('/api/colaboradores/?search=João')
        assert response.status_code == 200
        assert len(response.data) == 1

    def test_busca_sem_resultado_retorna_lista_vazia(self, client_autenticado, colaborador):
        response = client_autenticado.get('/api/colaboradores/?search=Inexistente')
        assert response.status_code == 200
        assert len(response.data) == 0

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/colaboradores/')
        assert response.status_code == 401

    def test_me_retorna_dados_do_colaborador_autenticado(self, client_autenticado, colaborador):
        response = client_autenticado.get('/api/colaboradores/me/')
        assert response.status_code == 200
        assert response.data['id'] == colaborador.id
        assert response.data['role'] == 'colaborador'
        assert response.data['user']['email'] == colaborador.user.email

    def test_me_sem_colaborador_vinculado_retorna_404(self, client_autenticado):
        response = client_autenticado.get('/api/colaboradores/me/')
        assert response.status_code == 404

    def test_delete_retorna_204_sem_deletar_fisicamente(self, client_autenticado, colaborador_outro):
        response = client_autenticado.delete(f'/api/colaboradores/{colaborador_outro.id}/')
        assert response.status_code == 204
        colaborador_outro.refresh_from_db()
        assert colaborador_outro.ativo is False

    def test_delete_seta_user_is_active_false(self, client_autenticado, colaborador_outro):
        client_autenticado.delete(f'/api/colaboradores/{colaborador_outro.id}/')
        colaborador_outro.user.refresh_from_db()
        assert colaborador_outro.user.is_active is False

    def test_desativar_desativa_user(self, client_autenticado, colaborador_outro):
        response = client_autenticado.post(f'/api/colaboradores/{colaborador_outro.id}/desativar/')
        assert response.status_code == 204
        colaborador_outro.refresh_from_db()
        colaborador_outro.user.refresh_from_db()
        assert colaborador_outro.ativo is False
        assert colaborador_outro.user.is_active is False

    def test_ativar_reativa_user(self, client_autenticado, colaborador_outro):
        colaborador_outro.ativo = False
        colaborador_outro.save()
        colaborador_outro.user.is_active = False
        colaborador_outro.user.save()
        response = client_autenticado.post(f'/api/colaboradores/{colaborador_outro.id}/ativar/')
        assert response.status_code == 200
        assert response.data['ativo'] is True
        colaborador_outro.user.refresh_from_db()
        assert colaborador_outro.user.is_active is True

    def test_patch_ignora_role_e_ativo(self, client_autenticado, colaborador_outro):
        response = client_autenticado.patch(
            f'/api/colaboradores/{colaborador_outro.id}/',
            {'funcao': 'Gerente', 'role': 'proprietario', 'ativo': False},
        )
        assert response.status_code == 200
        colaborador_outro.refresh_from_db()
        colaborador_outro.user.refresh_from_db()
        assert colaborador_outro.funcao == 'Gerente'
        assert colaborador_outro.role == 'colaborador'
        assert colaborador_outro.ativo is True
        assert colaborador_outro.user.is_active is True

    def test_agendamentos_pendentes_sem_agendamentos_retorna_false(self, client_autenticado, colaborador_outro):
        response = client_autenticado.get(f'/api/colaboradores/{colaborador_outro.id}/agendamentos-pendentes/')
        assert response.status_code == 200
        assert response.data['tem_pendentes'] is False
        assert response.data['total'] == 0

    def test_agendamentos_pendentes_com_futuro_retorna_true(self, client_autenticado, colaborador_outro, patch_tenant_middleware):
        from datetime import timedelta
        from django.utils import timezone
        from apps_work.agenda.models import Agendamento
        from apps_work.clientes.models import Cliente
        cliente = Cliente.objects.create(nome='Cliente Teste')
        Agendamento.objects.create(
            cliente=cliente,
            colaborador=colaborador_outro,
            data_hora=timezone.now() + timedelta(days=1),
            status='agendado',
        )
        response = client_autenticado.get(f'/api/colaboradores/{colaborador_outro.id}/agendamentos-pendentes/')
        assert response.status_code == 200
        assert response.data['tem_pendentes'] is True
        assert response.data['total'] == 1

    def test_agendamentos_pendentes_ignora_concluidos_e_cancelados(self, client_autenticado, colaborador_outro, patch_tenant_middleware):
        from datetime import timedelta
        from django.utils import timezone
        from apps_work.agenda.models import Agendamento
        from apps_work.clientes.models import Cliente
        cliente = Cliente.objects.create(nome='Cliente Teste 2')
        Agendamento.objects.create(
            cliente=cliente,
            colaborador=colaborador_outro,
            data_hora=timezone.now() + timedelta(days=1),
            status='concluido',
        )
        Agendamento.objects.create(
            cliente=cliente,
            colaborador=colaborador_outro,
            data_hora=timezone.now() + timedelta(days=2),
            status='cancelado',
        )
        response = client_autenticado.get(f'/api/colaboradores/{colaborador_outro.id}/agendamentos-pendentes/')
        assert response.data['tem_pendentes'] is False

    def test_remover_colaborador_deleta_fisicamente(self, client_autenticado, colaborador_outro):
        colab_id = colaborador_outro.id
        response = client_autenticado.delete(f'/api/colaboradores/{colab_id}/remover/')
        assert response.status_code == 204
        assert Colaborador.objects.filter(pk=colab_id).count() == 0

    def test_desativar_remove_colaborador_dos_servicos_vinculados(self, client_autenticado, colaborador_outro):
        from apps_work.servicos.models import Servico
        servico = Servico.objects.create(nome='Corte', duracao=30, preco='50.00')
        servico.colaboradores.add(colaborador_outro)

        client_autenticado.delete(f'/api/colaboradores/{colaborador_outro.id}/')

        assert not servico.colaboradores.filter(pk=colaborador_outro.pk).exists()

    def test_reativar_colaborador_sincroniza_user_is_active(self, patch_tenant_middleware, usuario):
        from apps_work.usuarios.services import ColaboradorService
        colaborador = Colaborador.objects.create(user=usuario, ativo=False)
        usuario.is_active = False
        usuario.save()
        ColaboradorService().reativar(colaborador)
        colaborador.refresh_from_db()
        usuario.refresh_from_db()
        assert colaborador.ativo is True
        assert usuario.is_active is True

    def test_remover_nulifica_agendamentos_preservando_historico(self, client_autenticado, colaborador_outro, patch_tenant_middleware):
        from datetime import timedelta
        from django.utils import timezone
        from apps_work.agenda.models import Agendamento
        from apps_work.clientes.models import Cliente
        cliente = Cliente.objects.create(nome='Cliente Remoção')
        ag = Agendamento.objects.create(
            cliente=cliente,
            colaborador=colaborador_outro,
            data_hora=timezone.now() - timedelta(days=1),
            status='concluido',
        )
        client_autenticado.delete(f'/api/colaboradores/{colaborador_outro.id}/remover/')
        ag.refresh_from_db()
        assert ag.colaborador is None


# --- ConviteColaboradorViewSet ---

@pytest.mark.django_db
class TestConviteAPI:
    def test_listar_convites_pendentes_retorna_200(self, client_autenticado, convite_valido):
        response = client_autenticado.get('/api/convites/')
        assert response.status_code == 200
        assert len(response.data) == 1

    def test_listar_nao_retorna_convites_aceitos(self, client_autenticado, convite_aceito):
        response = client_autenticado.get('/api/convites/')
        assert response.status_code == 200
        assert len(response.data) == 0

    def test_listar_nao_retorna_convites_expirados(self, client_autenticado, convite_expirado):
        response = client_autenticado.get('/api/convites/')
        assert response.status_code == 200
        assert len(response.data) == 0

    @patch('apps_work.usuarios.services.send_mail')
    def test_criar_convite_retorna_201(self, mock_mail, client_autenticado):
        payload = {'nome': 'Maria', 'email': 'maria@email.com'}
        response = client_autenticado.post('/api/convites/', payload)
        assert response.status_code == 201
        assert response.data['email'] == 'maria@email.com'

    @patch('apps_work.usuarios.services.send_mail')
    def test_criar_convite_respeita_rate_limit(self, mock_mail, client_autenticado):
        from django.core.cache import cache
        cache.clear()
        for i in range(5):
            response = client_autenticado.post('/api/convites/', {'nome': f'Pessoa {i}', 'email': f'pessoa{i}@email.com'})
            assert response.status_code == 201
        response = client_autenticado.post('/api/convites/', {'nome': 'Excedente', 'email': 'excedente@email.com'})
        assert response.status_code == 429

    def test_criar_convite_com_email_ja_pendente_retorna_400(self, client_autenticado, convite_valido):
        payload = {'nome': 'Outro', 'email': convite_valido.email}
        response = client_autenticado.post('/api/convites/', payload)
        assert response.status_code == 400
        assert 'pendente' in response.data['detail'].lower()

    @patch('apps_work.usuarios.services.send_mail')
    def test_criar_convite_apos_expiracao_retorna_201(self, mock_mail, client_autenticado, convite_expirado):
        payload = {'nome': 'Carlos', 'email': convite_expirado.email}
        response = client_autenticado.post('/api/convites/', payload)
        assert response.status_code == 201

    @patch('apps_work.usuarios.services.send_mail')
    def test_criar_convite_apos_aceito_retorna_201(self, mock_mail, client_autenticado, convite_aceito):
        payload = {'nome': 'Pedro', 'email': convite_aceito.email}
        response = client_autenticado.post('/api/convites/', payload)
        assert response.status_code == 201

    def test_cancelar_convite_retorna_204_e_remove(self, client_autenticado, convite_valido):
        response = client_autenticado.delete(f'/api/convites/{convite_valido.pk}/')
        assert response.status_code == 204
        assert ConviteColaborador.objects.filter(pk=convite_valido.pk).count() == 0

    def test_cancelar_convite_remove_convite_index(self, client_autenticado, convite_valido):
        from tenants.models import ConviteIndex
        ConviteIndex.objects.create(token=convite_valido.token, schema_name='test_empresa')
        client_autenticado.delete(f'/api/convites/{convite_valido.pk}/')
        assert ConviteIndex.objects.filter(token=convite_valido.token).count() == 0

    def test_cancelar_convite_colaborador_comum_retorna_403(self, patch_tenant_middleware, usuario, convite_valido):
        Colaborador.objects.create(user=usuario, role='colaborador')
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        client.force_authenticate(user=usuario)
        response = client.delete(f'/api/convites/{convite_valido.pk}/')
        assert response.status_code == 403
        assert ConviteColaborador.objects.filter(pk=convite_valido.pk).count() == 1

    def test_cancelar_convite_expirado_retorna_404(self, client_autenticado, convite_expirado):
        response = client_autenticado.delete(f'/api/convites/{convite_expirado.pk}/')
        assert response.status_code == 404

    def test_info_token_invalido_retorna_404(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        import uuid
        response = client.get(f'/api/convites/info/{uuid.uuid4()}/')
        assert response.status_code == 404

    def test_info_convite_valido_retorna_dados(self, patch_tenant_middleware, convite_valido):
        from tenants.models import ConviteIndex
        ConviteIndex.objects.create(token=convite_valido.token, schema_name='test_empresa')
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get(f'/api/convites/info/{convite_valido.token}/')
        assert response.status_code == 200
        assert response.data['nome'] == convite_valido.nome
        assert response.data['email'] == convite_valido.email

    def test_aceitar_por_token_invalido_retorna_404(self, patch_tenant_middleware):
        import uuid
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.post(f'/api/convites/aceitar/{uuid.uuid4()}/', {'senha': 'SenhaForte@2024!'})
        assert response.status_code == 404

    def test_aceitar_por_token_convite_ja_aceito_retorna_400(self, patch_tenant_middleware, convite_aceito):
        from tenants.models import ConviteIndex
        ConviteIndex.objects.create(token=convite_aceito.token, schema_name='test_empresa')
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.post(
            f'/api/convites/aceitar/{convite_aceito.token}/',
            {'senha': 'SenhaForte@2024!'},
        )
        assert response.status_code == 400
        assert 'já foi aceito' in response.data['detail']

    def test_aceitar_por_token_sem_senha_retorna_400(self, patch_tenant_middleware, convite_valido):
        from tenants.models import ConviteIndex
        ConviteIndex.objects.create(token=convite_valido.token, schema_name='test_empresa')
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.post(f'/api/convites/aceitar/{convite_valido.token}/', {})
        assert response.status_code == 400
        assert 'senha' in response.data['detail'].lower()

    def test_aceitar_por_token_retorna_201_com_access(self, patch_tenant_middleware, convite_valido):
        from tenants.models import ConviteIndex
        ConviteIndex.objects.create(token=convite_valido.token, schema_name='test_empresa')
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.post(
            f'/api/convites/aceitar/{convite_valido.token}/',
            {'senha': 'SenhaForte@2024!'},
        )
        assert response.status_code == 201
        assert 'access' in response.data
        assert 'refresh' in response.data
        assert response.cookies.get('refresh_token') is not None

    def test_aceitar_por_token_senha_fraca_retorna_400(self, patch_tenant_middleware, convite_valido):
        from tenants.models import ConviteIndex
        ConviteIndex.objects.create(token=convite_valido.token, schema_name='test_empresa')
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.post(
            f'/api/convites/aceitar/{convite_valido.token}/',
            {'senha': '123'},
        )
        assert response.status_code == 400

    def test_aceitar_por_token_tenant_inexistente_retorna_404(self, patch_tenant_middleware):
        from tenants.models import ConviteIndex
        import uuid
        token = uuid.uuid4()
        ConviteIndex.objects.create(token=token, schema_name='schema_que_nao_existe')
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.post(f'/api/convites/aceitar/{token}/', {'senha': 'SenhaForte@2024!'})
        assert response.status_code == 404

    def test_aceitar_por_token_convite_nao_encontrado_retorna_404(self, patch_tenant_middleware):
        from tenants.models import ConviteIndex
        import uuid
        token = uuid.uuid4()
        ConviteIndex.objects.create(token=token, schema_name='test_empresa')
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.post(f'/api/convites/aceitar/{token}/', {'senha': 'SenhaForte@2024!'})
        assert response.status_code == 404

    def test_info_tenant_inexistente_retorna_404(self, patch_tenant_middleware):
        from tenants.models import ConviteIndex
        import uuid
        token = uuid.uuid4()
        ConviteIndex.objects.create(token=token, schema_name='schema_que_nao_existe')
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get(f'/api/convites/info/{token}/')
        assert response.status_code == 404

    def test_info_convite_ja_aceito_retorna_404(self, patch_tenant_middleware, convite_aceito):
        from tenants.models import ConviteIndex
        ConviteIndex.objects.create(token=convite_aceito.token, schema_name='test_empresa')
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get(f'/api/convites/info/{convite_aceito.token}/')
        assert response.status_code == 404

    def test_info_convite_expirado_retorna_400(self, patch_tenant_middleware, convite_expirado):
        from tenants.models import ConviteIndex
        ConviteIndex.objects.create(token=convite_expirado.token, schema_name='test_empresa')
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get(f'/api/convites/info/{convite_expirado.token}/')
        assert response.status_code == 400

    def test_aceitar_por_token_email_ja_existente_retorna_400(self, patch_tenant_middleware, convite_valido):
        from tenants.models import ConviteIndex
        User.objects.create_user(
            username='ana@email.com', email='ana@email.com', password='SenhaTemp123!'
        )
        ConviteIndex.objects.create(token=convite_valido.token, schema_name='test_empresa')
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.post(
            f'/api/convites/aceitar/{convite_valido.token}/',
            {'senha': 'SenhaForte@2024!'},
        )
        assert response.status_code == 400
        assert 'vinculado' in response.data['detail']

    def test_get_authenticators_retorna_lista_vazia_para_acoes_publicas(self, patch_tenant_middleware):
        from apps_work.usuarios.views import ConviteColaboradorViewSet
        view = ConviteColaboradorViewSet()
        view.action = 'aceitar_por_token'
        assert view.get_authenticators() == []

    def test_get_authenticators_retorna_default_para_acoes_privadas(self, patch_tenant_middleware):
        from apps_work.usuarios.views import ConviteColaboradorViewSet
        view = ConviteColaboradorViewSet()
        view.action = 'list'
        assert len(view.get_authenticators()) > 0
