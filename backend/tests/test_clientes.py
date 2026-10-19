import pytest
from django.test import RequestFactory
from apps_work.clientes.models import Cliente, ObjetoCliente, Veiculo, Pet
from apps_work.clientes.validators import validar_placa_br
from rest_framework import serializers as drf_serializers


@pytest.mark.django_db
class TestClienteModel:
    def test_criar_cliente(self, tenant):
        cliente = Cliente.objects.create(
            nome='Carlos Mendes',
            telefone='11999999999',
            email='carlos@email.com',
        )
        assert cliente.id is not None
        assert cliente.nome == 'Carlos Mendes'

    def test_str_cliente(self):
        cliente = Cliente(nome='Ana Souza')
        assert str(cliente) == 'Ana Souza'

    def test_campos_opcionais_em_branco(self, tenant):
        cliente = Cliente.objects.create(nome='Pedro Lima')
        assert cliente.telefone == ''
        assert cliente.email == ''
        assert cliente.cpf == ''


@pytest.mark.django_db
class TestObjetoClienteStr:
    def test_str_objeto_cliente_base(self, tenant):
        cliente = Cliente.objects.create(nome='Maria Souza')
        obj = ObjetoCliente.objects.create(cliente=cliente, tipo='veiculo')
        assert str(obj) == 'Veículo — Maria Souza'

    def test_str_veiculo(self, tenant):
        cliente = Cliente.objects.create(nome='João')
        veiculo = Veiculo.objects.create(
            cliente=cliente, tipo='veiculo', modelo='Civic', marca='Honda', placa='ABC-1234'
        )
        assert str(veiculo) == 'Honda Civic (ABC-1234)'

    def test_str_pet(self, tenant):
        cliente = Cliente.objects.create(nome='Ana')
        pet = Pet.objects.create(cliente=cliente, tipo='pet', nome='Rex', especie='Cachorro')
        assert str(pet) == 'Rex'


class TestValidarPlaca:
    def test_placa_antigo_com_hifen_normaliza(self):
        assert validar_placa_br('ABC-1234') == 'ABC1234'

    def test_placa_antigo_sem_hifen(self):
        assert validar_placa_br('abc1234') == 'ABC1234'

    def test_placa_mercosul(self):
        assert validar_placa_br('ABC1D23') == 'ABC1D23'

    def test_placa_mercosul_minuscula(self):
        assert validar_placa_br('abc1d23') == 'ABC1D23'

    def test_placa_invalida_formato_errado_levanta_erro(self):
        with pytest.raises(drf_serializers.ValidationError):
            validar_placa_br('ABCD1234')

    def test_placa_invalida_so_numeros_levanta_erro(self):
        with pytest.raises(drf_serializers.ValidationError):
            validar_placa_br('12345678')

    def test_placa_vazia_levanta_erro(self):
        with pytest.raises(drf_serializers.ValidationError):
            validar_placa_br('')

    def test_placa_com_espacos_normaliza(self):
        assert validar_placa_br(' ABC-1234 ') == 'ABC1234'
