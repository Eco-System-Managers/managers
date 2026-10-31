from unittest.mock import patch

import pytest
from rest_framework.test import APIClient

from apps_work.clientes.models import Cliente, Pet, Veiculo


@pytest.fixture
def client_autenticado(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def cliente(patch_tenant_middleware):
    return Cliente.objects.create(nome='Carlos Silva', telefone='99999-0000', email='carlos@email.com')


@pytest.fixture
def outro_cliente(patch_tenant_middleware):
    return Cliente.objects.create(nome='Maria Souza', telefone='88888-1111')


@pytest.fixture
def veiculo(patch_tenant_middleware, cliente):
    return Veiculo.objects.create(cliente=cliente, tipo='veiculo', modelo='Civic', marca='Honda', placa='ABC-1234')


@pytest.fixture
def pet(patch_tenant_middleware, cliente):
    return Pet.objects.create(cliente=cliente, tipo='pet', nome='Rex', especie='Cachorro')


# --- ClienteViewSet ---

@pytest.mark.django_db
class TestClienteAPI:
    def test_listar_clientes_retorna_200(self, client_autenticado, cliente):
        response = client_autenticado.get('/api/v1/clientes/')
        assert response.status_code == 200
        assert response.data['count'] == 1

    def test_listar_nao_retorna_cliente_invisivel(self, client_autenticado, cliente):
        Cliente.objects.create(nome='Desvinculado', email='desvinculado@email.com', visivel=False)
        response = client_autenticado.get('/api/v1/clientes/')
        assert response.status_code == 200
        nomes = [c['nome'] for c in response.data['results']]
        assert 'Desvinculado' not in nomes
        assert cliente.nome in nomes

    def test_cliente_criado_manualmente_e_sempre_visivel(self, client_autenticado):
        response = client_autenticado.post('/api/v1/clientes/', {'nome': 'Cadastro Manual', 'telefone': '11999990000'})
        assert response.status_code == 201
        assert Cliente.objects.get(pk=response.data['id']).visivel is True

    def test_criar_cliente_retorna_201(self, client_autenticado):
        payload = {'nome': 'Novo Cliente', 'telefone': '11999990000'}
        response = client_autenticado.post('/api/v1/clientes/', payload)
        assert response.status_code == 201
        assert response.data['nome'] == 'Novo Cliente'

    def test_detalhar_cliente_retorna_200(self, client_autenticado, cliente):
        response = client_autenticado.get(f'/api/v1/clientes/{cliente.id}/')
        assert response.status_code == 200
        assert response.data['nome'] == cliente.nome

    def test_atualizar_cliente_retorna_200(self, client_autenticado, cliente):
        response = client_autenticado.patch(f'/api/v1/clientes/{cliente.id}/', {'telefone': '11999990001'})
        assert response.status_code == 200
        assert response.data['telefone'] == '11999990001'

    def test_deletar_cliente_retorna_204(self, client_autenticado, cliente):
        response = client_autenticado.delete(f'/api/v1/clientes/{cliente.id}/')
        assert response.status_code == 204
        assert Cliente.objects.filter(pk=cliente.pk).count() == 0

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware, cliente):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/v1/clientes/')
        assert response.status_code == 401

    def test_listagem_vem_paginada(self, client_autenticado, cliente):
        response = client_autenticado.get('/api/v1/clientes/')
        assert set(response.data) >= {'count', 'next', 'previous', 'results'}

    def test_pagina_traz_no_maximo_vinte(self, client_autenticado):
        for i in range(25):
            Cliente.objects.create(nome=f'Cliente {i:02d}', telefone=f'1199999{i:04d}')
        response = client_autenticado.get('/api/v1/clientes/')
        assert response.data['count'] == 25
        assert len(response.data['results']) == 20
        assert response.data['next'] is not None

    def test_segunda_pagina_traz_o_restante(self, client_autenticado):
        for i in range(25):
            Cliente.objects.create(nome=f'Cliente {i:02d}', telefone=f'1199999{i:04d}')
        response = client_autenticado.get('/api/v1/clientes/?page=2')
        assert len(response.data['results']) == 5
        assert response.data['next'] is None

    def test_paginas_nao_repetem_cliente(self, client_autenticado):
        """Sem ordenacao estavel o mesmo registro pode cair em duas paginas."""
        for i in range(25):
            Cliente.objects.create(nome=f'Cliente {i:02d}', telefone=f'1199999{i:04d}')
        p1 = client_autenticado.get('/api/v1/clientes/').data['results']
        p2 = client_autenticado.get('/api/v1/clientes/?page=2').data['results']
        ids = [c['id'] for c in p1] + [c['id'] for c in p2]
        assert len(ids) == len(set(ids)) == 25

    def test_busca_pagina_o_proprio_resultado(self, client_autenticado):
        for i in range(25):
            Cliente.objects.create(nome=f'Alvo {i:02d}', telefone=f'1199999{i:04d}')
        Cliente.objects.create(nome='Fora do filtro', telefone='11888880000')
        response = client_autenticado.get('/api/v1/clientes/?search=Alvo')
        assert response.data['count'] == 25
        assert len(response.data['results']) == 20

    def test_pagina_inexistente_retorna_404(self, client_autenticado, cliente):
        assert client_autenticado.get('/api/v1/clientes/?page=99').status_code == 404

    def test_buscar_por_nome_filtra_clientes(self, client_autenticado, cliente, outro_cliente):
        response = client_autenticado.get('/api/v1/clientes/?search=Carlos')
        assert response.status_code == 200
        assert response.data['count'] == 1
        assert response.data['results'][0]['nome'] == 'Carlos Silva'

    def test_buscar_por_telefone_filtra_clientes(self, client_autenticado, cliente, outro_cliente):
        response = client_autenticado.get('/api/v1/clientes/?search=99999')
        assert response.status_code == 200
        assert response.data['count'] == 1
        assert response.data['results'][0]['nome'] == 'Carlos Silva'

    def test_busca_sem_resultado_retorna_lista_vazia(self, client_autenticado, cliente):
        response = client_autenticado.get('/api/v1/clientes/?search=Inexistente')
        assert response.status_code == 200
        assert response.data['count'] == 0

    def test_listar_retorna_veiculos_e_pets_nested(self, client_autenticado, cliente, veiculo, pet):
        response = client_autenticado.get('/api/v1/clientes/')
        assert response.status_code == 200
        data = response.data['results'][0]
        assert len(data['veiculos']) == 1
        assert data['veiculos'][0]['modelo'] == 'Civic'
        assert len(data['pets']) == 1
        assert data['pets'][0]['nome'] == 'Rex'

    def test_action_objetos_retorna_lista_do_cliente(self, client_autenticado, cliente, veiculo, pet):
        response = client_autenticado.get(f'/api/v1/clientes/{cliente.id}/objetos/')
        assert response.status_code == 200
        assert len(response.data) == 2
        tipos = {obj['tipo'] for obj in response.data}
        assert tipos == {'veiculo', 'pet'}


# --- VeiculoViewSet ---

@pytest.mark.django_db
class TestVeiculoAPI:
    def test_listar_veiculos_retorna_200(self, client_autenticado, veiculo):
        response = client_autenticado.get('/api/v1/veiculos/')
        assert response.status_code == 200
        assert len(response.data['results']) == 1

    def test_criar_veiculo_seta_tipo_veiculo(self, client_autenticado, cliente):
        payload = {'cliente': cliente.id, 'modelo': 'Gol', 'marca': 'VW', 'placa': 'XYZ-9999', 'cor': 'Prata', 'porte': 'carro'}
        response = client_autenticado.post('/api/v1/veiculos/', payload)
        assert response.status_code == 201
        assert Veiculo.objects.get(pk=response.data['id']).tipo == 'veiculo'

    def test_filtrar_veiculo_por_cliente(self, client_autenticado, cliente, outro_cliente, veiculo):
        Veiculo.objects.create(cliente=outro_cliente, tipo='veiculo', modelo='Uno', marca='Fiat')
        response = client_autenticado.get(f'/api/v1/veiculos/?cliente={cliente.id}')
        assert response.status_code == 200
        assert len(response.data['results']) == 1
        assert response.data['results'][0]['modelo'] == 'Civic'

    def test_deletar_veiculo_retorna_204(self, client_autenticado, veiculo):
        response = client_autenticado.delete(f'/api/v1/veiculos/{veiculo.id}/')
        assert response.status_code == 204
        assert Veiculo.objects.filter(pk=veiculo.pk).count() == 0

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/v1/veiculos/')
        assert response.status_code == 401


# --- PetViewSet ---

@pytest.mark.django_db
class TestPetAPI:
    def test_listar_pets_retorna_200(self, client_autenticado, pet):
        response = client_autenticado.get('/api/v1/pets/')
        assert response.status_code == 200
        assert len(response.data['results']) == 1

    def test_criar_pet_seta_tipo_pet(self, client_autenticado, cliente):
        payload = {'cliente': cliente.id, 'nome': 'Bolinha', 'especie': 'Gato', 'porte': 'pequeno'}
        response = client_autenticado.post('/api/v1/pets/', payload)
        assert response.status_code == 201
        assert Pet.objects.get(pk=response.data['id']).tipo == 'pet'

    def test_filtrar_pet_por_cliente(self, client_autenticado, cliente, outro_cliente, pet):
        Pet.objects.create(cliente=outro_cliente, tipo='pet', nome='Mimi', especie='Gato')
        response = client_autenticado.get(f'/api/v1/pets/?cliente={cliente.id}')
        assert response.status_code == 200
        assert len(response.data['results']) == 1
        assert response.data['results'][0]['nome'] == 'Rex'

    def test_deletar_pet_retorna_204(self, client_autenticado, pet):
        response = client_autenticado.delete(f'/api/v1/pets/{pet.id}/')
        assert response.status_code == 204
        assert Pet.objects.filter(pk=pet.pk).count() == 0

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/v1/pets/')
        assert response.status_code == 401


# --- Validações de campos ---

@pytest.mark.django_db
class TestClienteValidacoes:
    def test_telefone_com_poucos_digitos_retorna_400(self, client_autenticado):
        response = client_autenticado.post('/api/v1/clientes/', {'nome': 'Ana', 'telefone': '119999'})
        assert response.status_code == 400

    def test_telefone_com_ddd_invalido_retorna_400(self, client_autenticado):
        response = client_autenticado.post('/api/v1/clientes/', {'nome': 'Ana', 'telefone': '01999990000'})
        assert response.status_code == 400

    def test_telefone_celular_sem_9_retorna_400(self, client_autenticado):
        response = client_autenticado.post('/api/v1/clientes/', {'nome': 'Ana', 'telefone': '11899990000'})
        assert response.status_code == 400

    def test_telefone_valido_salva_apenas_digitos(self, client_autenticado):
        response = client_autenticado.post('/api/v1/clientes/', {'nome': 'Ana', 'telefone': '(11) 99999-0000'})
        assert response.status_code == 201
        assert response.data['telefone'] == '11999990000'

    def test_telefone_vazio_retorna_400(self, client_autenticado):
        response = client_autenticado.post('/api/v1/clientes/', {'nome': 'Ana', 'telefone': ''})
        assert response.status_code == 400

    def test_sem_telefone_retorna_400(self, client_autenticado):
        response = client_autenticado.post('/api/v1/clientes/', {'nome': 'Ana'})
        assert response.status_code == 400

    def test_sem_nome_retorna_400(self, client_autenticado):
        response = client_autenticado.post('/api/v1/clientes/', {'telefone': '11999990000'})
        assert response.status_code == 400

    def test_cpf_com_menos_de_11_digitos_retorna_400(self, client_autenticado):
        response = client_autenticado.post('/api/v1/clientes/', {'nome': 'Ana', 'telefone': '11999990000', 'cpf': '1234567890'})
        assert response.status_code == 400

    def test_cpf_com_11_digitos_aceito(self, client_autenticado):
        response = client_autenticado.post('/api/v1/clientes/', {'nome': 'Ana', 'telefone': '11999990000', 'cpf': '12345678901'})
        assert response.status_code == 201
        assert response.data['cpf'] == '12345678901'

    def test_cpf_duplicado_retorna_400(self, client_autenticado):
        Cliente.objects.create(nome='Carlos', cpf='12345678901')
        response = client_autenticado.post('/api/v1/clientes/', {'nome': 'Ana', 'telefone': '11999990000', 'cpf': '12345678901'})
        assert response.status_code == 400

    def test_cpf_duplicado_permite_ao_editar_proprio_cliente(self, client_autenticado):
        cliente = Cliente.objects.create(nome='Carlos', cpf='12345678901')
        response = client_autenticado.patch(f'/api/v1/clientes/{cliente.id}/', {'cpf': '12345678901'})
        assert response.status_code == 200

    def test_cpf_vazio_aceito(self, client_autenticado):
        response = client_autenticado.post('/api/v1/clientes/', {'nome': 'Ana', 'telefone': '11999990000', 'cpf': ''})
        assert response.status_code == 201


# --- Foto do cliente vinda do Service Manage ---

@pytest.mark.django_db
class TestFotoDoClienteNoPainel:
    URL_FOTO = 'apps_work.empresa.services.ArmazenamentoImagemService.url'

    def test_cliente_com_foto_expoe_url_assinada(self, client_autenticado, cliente):
        cliente.foto_chave = 'consumidores/abc.webp'
        cliente.save(update_fields=['foto_chave'])

        with patch(self.URL_FOTO, return_value='https://x/assinada') as gerar:
            resposta = client_autenticado.get(f'/api/v1/clientes/{cliente.id}/')

        assert resposta.data['foto'] == 'https://x/assinada'
        assert gerar.call_args.args[0] == 'consumidores/abc.webp'

    def test_cliente_sem_foto_devolve_vazio(self, client_autenticado, cliente):
        resposta = client_autenticado.get(f'/api/v1/clientes/{cliente.id}/')
        assert resposta.data['foto'] == ''

    def test_painel_nao_altera_a_foto(self, client_autenticado, cliente):
        """A foto pertence ao cadastro do consumidor. Aceitar edição aqui
        criaria um valor que a próxima sincronização apagaria sem aviso."""
        cliente.foto_chave = 'consumidores/abc.webp'
        cliente.save(update_fields=['foto_chave'])

        with patch(self.URL_FOTO, return_value=''):
            client_autenticado.patch(
                f'/api/v1/clientes/{cliente.id}/',
                {'foto': 'https://invasor/outra.webp'},
                format='json',
            )

        cliente.refresh_from_db()
        assert cliente.foto_chave == 'consumidores/abc.webp'
