"""O porte do veículo e do pet, e os serviços de um porte só (Work Manage)."""
import pytest
from rest_framework.test import APIClient

from apps_work.clientes.models import Cliente, ObjetoCliente, Pet, Veiculo, porte_do_objeto
from apps_work.empresa.models import EmpresaConfig
from apps_work.kanban.models import AtendimentoKanban, EtapaKanban
from apps_work.servicos.models import Servico


@pytest.fixture
def api(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def lava_rapido(patch_tenant_middleware):
    return EmpresaConfig.objects.create(pk=1, nichos=['lava_rapido'], tipo_agenda='kanban', tipo_objeto='veiculo')


@pytest.fixture
def cliente(patch_tenant_middleware):
    return Cliente.objects.create(nome='Carlos', telefone='11999990000')


@pytest.fixture
def carro(cliente):
    return Veiculo.objects.create(
        cliente=cliente, tipo='veiculo', placa='ABC1D23', marca='VW', modelo='Gol', cor='Prata', porte='carro',
    )


def _servico(nome, porte=''):
    return Servico.objects.create(nome=nome, nicho='lava_rapido', porte=porte, duracao=40, preco='40.00')


@pytest.mark.django_db
class TestPorteNoCadastro:
    def test_veiculo_novo_exige_o_porte(self, api, cliente):
        dados = {'cliente': cliente.id, 'placa': 'ABC1D23', 'marca': 'VW', 'modelo': 'Gol', 'cor': 'Prata'}

        resposta = api.post('/api/v1/veiculos/', dados)

        assert resposta.status_code == 400
        assert 'porte' in resposta.data['fields']

    def test_veiculo_com_porte(self, api, cliente):
        dados = {
            'cliente': cliente.id, 'placa': 'ABC1D23', 'marca': 'VW', 'modelo': 'Gol', 'cor': 'Prata',
            'porte': 'moto',
        }

        resposta = api.post('/api/v1/veiculos/', dados)

        assert resposta.status_code == 201
        assert resposta.data['porte'] == 'moto'

    def test_porte_de_pet_nao_serve_para_veiculo(self, api, cliente):
        dados = {
            'cliente': cliente.id, 'placa': 'ABC1D23', 'marca': 'VW', 'modelo': 'Gol', 'cor': 'Prata',
            'porte': 'grande',
        }

        assert api.post('/api/v1/veiculos/', dados).status_code == 400

    def test_pet_novo_exige_o_porte(self, api, cliente):
        resposta = api.post('/api/v1/pets/', {'cliente': cliente.id, 'nome': 'Rex'})

        assert resposta.status_code == 400
        assert 'porte' in resposta.data['fields']

    def test_porte_vazio_e_recusado(self, api, cliente):
        resposta = api.post('/api/v1/pets/', {'cliente': cliente.id, 'nome': 'Rex', 'porte': ''})

        assert resposta.status_code == 400
        assert 'porte' in resposta.data['fields']

    def test_cadastro_antigo_sem_porte_continua_editavel(self, api, cliente):
        # Editar outro campo de um veículo de antes do porte não é barrado.
        antigo = Veiculo.objects.create(
            cliente=cliente, tipo='veiculo', placa='ABC1D23', marca='VW', modelo='Gol', cor='Prata',
        )

        resposta = api.patch(f'/api/v1/veiculos/{antigo.id}/', {'cor': 'Preto'})

        assert resposta.status_code == 200

    def test_porte_do_objeto_le_o_veiculo_e_o_pet(self, cliente, carro):
        pet = Pet.objects.create(cliente=cliente, tipo='pet', nome='Rex', porte='gigante')

        assert porte_do_objeto(ObjetoCliente.objects.get(pk=carro.pk)) == 'carro'
        assert porte_do_objeto(ObjetoCliente.objects.get(pk=pet.pk)) == 'gigante'
        assert porte_do_objeto(carro) == 'carro'


@pytest.mark.django_db
class TestServicoDeUmPorte:
    def test_servico_com_o_porte_do_que_o_negocio_atende(self, api, lava_rapido):
        resposta = api.post('/api/v1/servicos/', {'nome': 'Lavagem', 'duracao': 20, 'preco': '25.00', 'porte': 'moto'})

        assert resposta.status_code == 201
        assert resposta.data['porte'] == 'moto'

    def test_porte_de_pet_num_lava_rapido(self, api, lava_rapido):
        resposta = api.post(
            '/api/v1/servicos/', {'nome': 'Banho', 'duracao': 20, 'preco': '25.00', 'porte': 'pequeno'},
        )

        assert resposta.status_code == 400
        assert 'porte' in resposta.data['fields']

    def test_modo_horario_nao_tem_porte(self, api, patch_tenant_middleware):
        EmpresaConfig.objects.create(pk=1, nichos=['barbearia'])

        resposta = api.post('/api/v1/servicos/', {'nome': 'Corte', 'duracao': 30, 'preco': '50.00', 'porte': 'moto'})

        assert resposta.status_code == 400

    def test_sem_porte_vale_para_qualquer_um(self, api, lava_rapido):
        resposta = api.post('/api/v1/servicos/', {'nome': 'Aspirar', 'duracao': 20, 'preco': '15.00'})

        assert resposta.status_code == 201
        assert resposta.data['porte'] == ''

    def test_filtro_traz_os_do_porte_e_os_sem_porte(self, api, lava_rapido):
        _servico('Lavagem moto', 'moto')
        _servico('Lavagem carro', 'carro')
        _servico('Aspirar')

        resposta = api.get('/api/v1/servicos/?porte=moto')

        assert sorted(s['nome'] for s in resposta.data['results']) == ['Aspirar', 'Lavagem moto']

    def test_serve_para(self):
        moto = Servico(porte='moto')

        assert moto.serve_para('moto')
        assert not moto.serve_para('carro')
        assert moto.serve_para('')  # objeto sem porte: não há com o que comparar
        assert Servico(porte='').serve_para('caminhao')


@pytest.mark.django_db
class TestPorteNoAtendimento:
    @pytest.fixture
    def etapa(self, patch_tenant_middleware):
        return EtapaKanban.objects.create(nome='Aguardando', ordem=0)

    def _receber(self, api, etapa, objeto, servico):
        return api.post('/api/v1/kanban/atendimentos/', {
            'etapa': etapa.id, 'objeto': objeto.id, 'servico': servico.id,
        })

    def test_servico_de_outro_porte_e_recusado(self, api, lava_rapido, etapa, carro):
        resposta = self._receber(api, etapa, carro, _servico('Lavagem moto', 'moto'))

        assert resposta.status_code == 400
        assert resposta.data['code'] == 'servico_de_outro_porte'
        assert not AtendimentoKanban.objects.exists()

    def test_servico_do_porte(self, api, lava_rapido, etapa, carro):
        assert self._receber(api, etapa, carro, _servico('Lavagem carro', 'carro')).status_code == 201

    def test_servico_sem_porte_atende_qualquer_um(self, api, lava_rapido, etapa, carro):
        assert self._receber(api, etapa, carro, _servico('Aspirar')).status_code == 201

    def test_veiculo_sem_porte_aceita_qualquer_servico(self, api, lava_rapido, etapa, cliente):
        antigo = Veiculo.objects.create(cliente=cliente, tipo='veiculo', placa='XYZ9A87', marca='Fiat', modelo='Uno')

        assert self._receber(api, etapa, antigo, _servico('Lavagem moto', 'moto')).status_code == 201

    def test_trocar_para_servico_de_outro_porte_e_recusado(self, api, lava_rapido, etapa, carro):
        atendimento = AtendimentoKanban.objects.create(etapa=etapa, objeto=carro, servico=_servico('Aspirar'))

        resposta = api.patch(
            f'/api/v1/kanban/atendimentos/{atendimento.id}/', {'servico': _servico('Lavagem moto', 'moto').id},
        )

        assert resposta.status_code == 400
        assert resposta.data['code'] == 'servico_de_outro_porte'
