import pytest
from django.contrib.auth.models import User
from rest_framework.test import APIClient

from apps_work.clientes.models import Cliente
from apps_work.contratos.models import Contrato, ModeloContrato, StatusContrato
from tenants.models import Membro


@pytest.fixture
def client_autenticado(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def cliente(patch_tenant_middleware):
    return Cliente.objects.create(nome='Ana Lima', telefone='11999990000')


def _contrato(cliente, titulo='Contrato', status=StatusContrato.PENDENTE):
    return Contrato.objects.create(
        cliente=cliente, titulo=titulo, corpo='Corpo do contrato.', status=status,
    )


@pytest.mark.django_db
class TestContratoAPI:
    URL = '/api/v1/contratos/'

    def test_listar_retorna_200(self, client_autenticado, cliente):
        _contrato(cliente)
        assert client_autenticado.get(self.URL).status_code == 200

    def test_listagem_vem_paginada(self, client_autenticado, cliente):
        _contrato(cliente)
        response = client_autenticado.get(self.URL)
        assert set(response.data) >= {'count', 'next', 'previous', 'results'}

    def test_pagina_traz_no_maximo_vinte(self, client_autenticado, cliente):
        for i in range(25):
            _contrato(cliente, titulo=f'Contrato {i:02d}')
        response = client_autenticado.get(self.URL)
        assert response.data['count'] == 25
        assert len(response.data['results']) == 20
        assert response.data['next'] is not None

    def test_segunda_pagina_traz_o_restante(self, client_autenticado, cliente):
        for i in range(25):
            _contrato(cliente, titulo=f'Contrato {i:02d}')
        response = client_autenticado.get(f'{self.URL}?page=2')
        assert len(response.data['results']) == 5
        assert response.data['next'] is None

    def test_paginas_nao_repetem_contrato(self, client_autenticado, cliente):
        """Contratos criados no mesmo instante precisam de desempate estavel,
        senao o mesmo registro cai em duas paginas e outro some."""
        for i in range(25):
            _contrato(cliente, titulo=f'Contrato {i:02d}')
        p1 = client_autenticado.get(self.URL).data['results']
        p2 = client_autenticado.get(f'{self.URL}?page=2').data['results']
        ids = [c['id'] for c in p1] + [c['id'] for c in p2]
        assert len(ids) == len(set(ids)) == 25

    def test_filtra_por_status(self, client_autenticado, cliente):
        _contrato(cliente, titulo='Pendente', status=StatusContrato.PENDENTE)
        _contrato(cliente, titulo='Assinado', status=StatusContrato.ASSINADO)
        response = client_autenticado.get(f'{self.URL}?status=assinado')
        assert response.data['count'] == 1
        assert response.data['results'][0]['titulo'] == 'Assinado'

    def test_filtra_por_cliente(self, client_autenticado, cliente):
        outro = Cliente.objects.create(nome='Bruno Reis', telefone='11888880000')
        _contrato(cliente, titulo='Do Ana')
        _contrato(outro, titulo='Do Bruno')
        response = client_autenticado.get(f'{self.URL}?cliente={cliente.id}')
        assert response.data['count'] == 1
        assert response.data['results'][0]['titulo'] == 'Do Ana'

    def test_filtro_pagina_o_proprio_resultado(self, client_autenticado, cliente):
        for i in range(25):
            _contrato(cliente, titulo=f'Assinado {i:02d}', status=StatusContrato.ASSINADO)
        _contrato(cliente, titulo='Fora do filtro', status=StatusContrato.PENDENTE)
        response = client_autenticado.get(f'{self.URL}?status=assinado')
        assert response.data['count'] == 25
        assert len(response.data['results']) == 20

    def test_sem_auth_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        assert client.get(self.URL).status_code == 401


@pytest.mark.django_db
class TestEnviarContrato:
    def _url(self, contrato):
        return f'/api/v1/contratos/{contrato.pk}/enviar/'

    def test_envia_email_com_link_de_assinatura(self, client_autenticado, cliente, mailoutbox):
        cliente.email = 'ana@email.com'
        cliente.save()
        contrato = _contrato(cliente)
        response = client_autenticado.post(self._url(contrato))
        assert response.status_code == 200
        assert response.data['status'] == StatusContrato.ENVIADO
        assert len(mailoutbox) == 1
        assert mailoutbox[0].to == ['ana@email.com']
        assert f'/contrato/test_empresa/{contrato.token}' in mailoutbox[0].body
        assert mailoutbox[0].alternatives  # versão HTML

    def test_falha_no_smtp_nao_vira_500(self, client_autenticado, cliente):
        """O e-mail sai por task: erro de SMTP fica fora da resposta."""
        from unittest.mock import patch
        cliente.email = 'ana@email.com'
        cliente.save()
        contrato = _contrato(cliente)
        with patch('core.email.send_mail', side_effect=OSError('smtp fora')):
            response = client_autenticado.post(self._url(contrato))
        assert response.status_code == 200


@pytest.fixture
def client_colaborador(patch_tenant_middleware, tenant):
    user = User.objects.create_user(username='bia@x.com', email='bia@x.com', password='SenhaForte123!')
    Membro.objects.create(user=user, tenant=tenant, papel='colaborador')
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=user)
    return client


@pytest.mark.django_db
class TestMarcarContrato:
    """O dono registra o que aconteceu fora do sistema (PDF pelo WhatsApp, papel)."""

    def _url(self, contrato):
        return f'/api/v1/contratos/{contrato.pk}/marcar/'

    def test_pendente_vira_enviado(self, client_autenticado, cliente):
        contrato = _contrato(cliente)
        response = client_autenticado.post(self._url(contrato), {'status': 'enviado'})
        assert response.status_code == 200
        assert response.data['status'] == 'enviado'

    def test_enviado_nao_e_enviado_de_novo(self, client_autenticado, cliente):
        contrato = _contrato(cliente, status=StatusContrato.ENVIADO)
        response = client_autenticado.post(self._url(contrato), {'status': 'enviado'})
        assert response.status_code == 400
        assert response.data['code'] == 'contrato_ja_enviado'

    def test_assinado_registra_o_nome_e_a_hora_sem_ip(self, client_autenticado, cliente):
        contrato = _contrato(cliente, status=StatusContrato.ENVIADO)
        response = client_autenticado.post(self._url(contrato), {'status': 'assinado'})
        assert response.status_code == 200
        assert response.data['status'] == 'assinado'
        assert response.data['nome_assinante'] == 'Ana Lima'
        assert response.data['assinado_em'] is not None
        assert response.data['ip_assinante'] is None

    def test_recusado_e_final(self, client_autenticado, cliente):
        contrato = _contrato(cliente)
        assert client_autenticado.post(self._url(contrato), {'status': 'recusado'}).data['status'] == 'recusado'
        response = client_autenticado.post(self._url(contrato), {'status': 'assinado'})
        assert response.status_code == 400
        assert response.data['code'] == 'contrato_finalizado'

    def test_status_fora_da_lista_e_erro_de_campo(self, client_autenticado, cliente):
        response = client_autenticado.post(self._url(_contrato(cliente)), {'status': 'pendente'})
        assert response.status_code == 400
        assert 'status' in response.data['fields']

    def test_assinado_nao_pode_ser_apagado(self, client_autenticado, cliente):
        contrato = _contrato(cliente, status=StatusContrato.ASSINADO)
        response = client_autenticado.delete(f'/api/v1/contratos/{contrato.pk}/')
        assert response.status_code == 400
        assert response.data['code'] == 'contrato_assinado'
        assert client_autenticado.delete(f'/api/v1/contratos/{_contrato(cliente).pk}/').status_code == 204


@pytest.mark.django_db
class TestModelos:
    URL = '/api/v1/contratos/modelos/'

    def test_so_o_proprietario_escreve(self, client_autenticado, client_colaborador):
        dados = {'titulo': 'Padrão', 'corpo': 'Eu, {{cliente_nome}}, concordo.'}
        assert client_colaborador.post(self.URL, dados).status_code == 403
        assert client_autenticado.post(self.URL, dados).status_code == 201
        assert client_colaborador.get(self.URL).status_code == 200

    def test_filtra_por_ativo(self, client_autenticado):
        ModeloContrato.objects.create(titulo='Ativo', corpo='x')
        ModeloContrato.objects.create(titulo='Velho', corpo='x', ativo=False)
        titulos = [m['titulo'] for m in client_autenticado.get(f'{self.URL}?ativo=true').data['results']]
        assert titulos == ['Ativo']
        assert len(client_autenticado.get(self.URL).data['results']) == 2
