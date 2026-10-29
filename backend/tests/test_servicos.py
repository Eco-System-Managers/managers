import pytest
from decimal import Decimal

from apps_work.servicos.models import Servico
from apps_work.servicos.serializers import ServicoSerializer


@pytest.mark.django_db
class TestServicoModel:
    def test_criar_servico(self, tenant):
        servico = Servico.objects.create(
            nome='Corte de cabelo',
            duracao=30,
            preco='50.00',
        )
        assert servico.id is not None
        assert servico.nome == 'Corte de cabelo'

    def test_str_servico(self):
        servico = Servico(nome='Manicure')
        assert str(servico) == 'Manicure'

    def test_ativo_padrao(self, tenant):
        servico = Servico.objects.create(
            nome='Escova',
            duracao=45,
            preco='35.00',
        )
        assert servico.ativo is True


# ---------------------------------------------------------------------------
# Servico.calcular_taxa_cancelamento()
# ---------------------------------------------------------------------------

class TestCalcularTaxaCancelamento:
    def test_tipo_em_branco_retorna_zero(self):
        servico = Servico(nome='Corte', duracao=30, preco=Decimal('50.00'), taxa_cancelamento_tipo='')
        assert servico.calcular_taxa_cancelamento() == Decimal('0')

    def test_tipo_valor_retorna_valor_fixo_configurado(self):
        servico = Servico(
            nome='Corte', duracao=30, preco=Decimal('50.00'),
            taxa_cancelamento_tipo='valor', taxa_cancelamento_valor=Decimal('15.00'),
        )
        assert servico.calcular_taxa_cancelamento() == Decimal('15.00')

    def test_tipo_percentual_calcula_sobre_o_preco(self):
        servico = Servico(
            nome='Corte', duracao=30, preco=Decimal('100.00'),
            taxa_cancelamento_tipo='percentual', taxa_cancelamento_valor=Decimal('20'),
        )
        assert servico.calcular_taxa_cancelamento() == Decimal('20.00')

    def test_tipo_percentual_calcula_sobre_outro_preco(self):
        servico = Servico(
            nome='Barba', duracao=20, preco=Decimal('150.00'),
            taxa_cancelamento_tipo='percentual', taxa_cancelamento_valor=Decimal('10'),
        )
        assert servico.calcular_taxa_cancelamento() == Decimal('15.00')


# ---------------------------------------------------------------------------
# ServicoSerializer — validação da taxa de cancelamento
# ---------------------------------------------------------------------------

@pytest.mark.django_db
class TestServicoSerializerTaxaCancelamento:
    @pytest.fixture(autouse=True)
    def negocio_de_um_nicho(self, tenant):
        # O serializer põe o serviço no único nicho do negócio.
        from apps_work.empresa.models import EmpresaConfig
        EmpresaConfig.objects.create(pk=1, nichos=['barbearia'])

    def _payload(self, **overrides):
        payload = {
            'nome': 'Corte', 'duracao': 30, 'preco': '100.00',
            'taxa_cancelamento_tipo': '', 'taxa_cancelamento_valor': '0',
        }
        payload.update(overrides)
        return payload

    def test_percentual_acima_de_30_e_rejeitado(self):
        serializer = ServicoSerializer(data=self._payload(
            taxa_cancelamento_tipo='percentual', taxa_cancelamento_valor='31',
        ))
        assert serializer.is_valid() is False
        assert 'taxa_cancelamento_valor' in serializer.errors

    def test_percentual_entre_0_e_30_e_aceito(self):
        serializer = ServicoSerializer(data=self._payload(
            taxa_cancelamento_tipo='percentual', taxa_cancelamento_valor='20',
        ))
        assert serializer.is_valid() is True, serializer.errors

    def test_valor_fixo_acima_de_30_por_cento_do_preco_e_rejeitado(self):
        # preco=100.00 -> limite de 30.00
        serializer = ServicoSerializer(data=self._payload(
            taxa_cancelamento_tipo='valor', taxa_cancelamento_valor='31.00',
        ))
        assert serializer.is_valid() is False
        assert 'taxa_cancelamento_valor' in serializer.errors

    def test_valor_fixo_dentro_de_30_por_cento_do_preco_e_aceito(self):
        serializer = ServicoSerializer(data=self._payload(
            taxa_cancelamento_tipo='valor', taxa_cancelamento_valor='25.00',
        ))
        assert serializer.is_valid() is True, serializer.errors

    def test_tipo_em_branco_com_valor_zero_e_aceito(self):
        serializer = ServicoSerializer(data=self._payload(
            taxa_cancelamento_tipo='', taxa_cancelamento_valor='0',
        ))
        assert serializer.is_valid() is True, serializer.errors
