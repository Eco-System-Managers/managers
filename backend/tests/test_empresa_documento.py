import pytest
from rest_framework.exceptions import ValidationError
from rest_framework.test import APIClient

from apps_work.empresa.models import EmpresaConfig
from apps_work.empresa.validators import validar_documento

CNPJ_VALIDO = '11222333000181'
CNPJ_FORMATADO = '11.222.333/0001-81'
CPF_VALIDO = '52998224725'
CPF_FORMATADO = '529.982.247-25'


@pytest.fixture
def client_autenticado(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


class TestValidarDocumento:
    def test_cpf_valido_retorna_digitos(self):
        assert validar_documento(CPF_VALIDO, 'cpf') == CPF_VALIDO

    def test_cpf_formatado_e_normalizado(self):
        assert validar_documento(CPF_FORMATADO, 'cpf') == CPF_VALIDO

    def test_cpf_com_digito_verificador_errado_lanca_excecao(self):
        with pytest.raises(ValidationError):
            validar_documento('52998224726', 'cpf')

    def test_cpf_com_todos_digitos_iguais_lanca_excecao(self):
        with pytest.raises(ValidationError):
            validar_documento('11111111111', 'cpf')

    def test_cpf_com_menos_de_11_digitos_lanca_excecao(self):
        with pytest.raises(ValidationError):
            validar_documento('5299822472', 'cpf')

    def test_cnpj_valido_retorna_digitos(self):
        assert validar_documento(CNPJ_VALIDO, 'cnpj') == CNPJ_VALIDO

    def test_cnpj_formatado_e_normalizado(self):
        assert validar_documento(CNPJ_FORMATADO, 'cnpj') == CNPJ_VALIDO

    def test_cnpj_com_digito_verificador_errado_lanca_excecao(self):
        with pytest.raises(ValidationError):
            validar_documento('11222333000182', 'cnpj')

    def test_cnpj_com_todos_digitos_iguais_lanca_excecao(self):
        with pytest.raises(ValidationError):
            validar_documento('11111111111111', 'cnpj')

    def test_cpf_valido_rejeitado_quando_tipo_e_cnpj(self):
        with pytest.raises(ValidationError):
            validar_documento(CPF_VALIDO, 'cnpj')

    def test_tipo_desconhecido_lanca_excecao(self):
        with pytest.raises(ValidationError):
            validar_documento(CPF_VALIDO, 'rg')

    def test_documento_vazio_lanca_excecao(self):
        with pytest.raises(ValidationError):
            validar_documento('', 'cpf')


@pytest.mark.django_db
class TestDocumentoNaConfigAPI:
    def test_salvar_cnpj_valido_retorna_200(self, client_autenticado):
        response = client_autenticado.patch(
            '/api/empresa/config/',
            {'documento': CNPJ_FORMATADO, 'tipo_documento': 'cnpj'},
            format='json',
        )
        assert response.status_code == 200

    def test_documento_salvo_sem_mascara(self, client_autenticado):
        client_autenticado.patch(
            '/api/empresa/config/',
            {'documento': CNPJ_FORMATADO, 'tipo_documento': 'cnpj'},
            format='json',
        )
        assert EmpresaConfig.objects.get(pk=1).documento == CNPJ_VALIDO

    def test_salvar_cpf_valido_retorna_200(self, client_autenticado):
        response = client_autenticado.patch(
            '/api/empresa/config/',
            {'documento': CPF_FORMATADO, 'tipo_documento': 'cpf'},
            format='json',
        )
        assert response.status_code == 200

    def test_documento_invalido_retorna_400(self, client_autenticado):
        response = client_autenticado.patch(
            '/api/empresa/config/',
            {'documento': '12345678901', 'tipo_documento': 'cpf'},
            format='json',
        )
        assert response.status_code == 400

    def test_documento_sem_tipo_retorna_400(self, client_autenticado):
        response = client_autenticado.patch(
            '/api/empresa/config/',
            {'documento': CPF_VALIDO},
            format='json',
        )
        assert response.status_code == 400

    def test_tipo_sem_documento_retorna_400(self, client_autenticado):
        response = client_autenticado.patch(
            '/api/empresa/config/',
            {'tipo_documento': 'cpf'},
            format='json',
        )
        assert response.status_code == 400

    def test_concluir_onboarding_sem_documento_retorna_400(self, client_autenticado):
        response = client_autenticado.patch(
            '/api/empresa/config/',
            {'onboarding_concluido': True},
            format='json',
        )
        assert response.status_code == 400

    def test_concluir_onboarding_sem_documento_informa_codigo(self, client_autenticado):
        response = client_autenticado.patch(
            '/api/empresa/config/',
            {'onboarding_concluido': True},
            format='json',
        )
        # O DRF embrulha cada valor do dict de erro numa lista — mesmo formato
        # que o resto da API já devolve (ver AgendamentoService.cobrar).
        assert response.data['code'][0] == 'documento_obrigatorio'

    def test_concluir_onboarding_com_documento_retorna_200(self, client_autenticado):
        response = client_autenticado.patch(
            '/api/empresa/config/',
            {'onboarding_concluido': True, 'documento': CPF_VALIDO, 'tipo_documento': 'cpf'},
            format='json',
        )
        assert response.status_code == 200

    def test_editar_config_de_negocio_ja_concluido_sem_documento_retorna_400(self, client_autenticado):
        """Tenant antigo, criado antes da regra: continua lendo normalmente,
        mas a próxima alteração exige o documento."""
        EmpresaConfig.objects.create(pk=1, nome='Antigo', onboarding_concluido=True)
        response = client_autenticado.patch(
            '/api/empresa/config/', {'nome': 'Antigo Editado'}, format='json'
        )
        assert response.status_code == 400

    def test_negocio_ja_concluido_sem_documento_ainda_pode_ser_lido(self, client_autenticado):
        EmpresaConfig.objects.create(pk=1, nome='Antigo', onboarding_concluido=True)
        response = client_autenticado.get('/api/empresa/config/')
        assert response.status_code == 200

    def test_documento_aparece_na_resposta(self, client_autenticado):
        client_autenticado.patch(
            '/api/empresa/config/',
            {'documento': CPF_VALIDO, 'tipo_documento': 'cpf'},
            format='json',
        )
        response = client_autenticado.get('/api/empresa/config/')
        assert response.data['documento'] == CPF_VALIDO

    def test_tipo_documento_aparece_na_resposta(self, client_autenticado):
        client_autenticado.patch(
            '/api/empresa/config/',
            {'documento': CPF_VALIDO, 'tipo_documento': 'cpf'},
            format='json',
        )
        response = client_autenticado.get('/api/empresa/config/')
        assert response.data['tipo_documento'] == 'cpf'


# --- Cadastros anteriores à regra do documento ---

@pytest.mark.django_db
class TestNegocioConcluidoSemDocumento:
    """Negócios que concluíram o onboarding antes da exigência do documento
    ficaram com o campo vazio. Eles precisam continuar operando o cadastro."""

    @pytest.fixture
    def legado(self, patch_tenant_middleware):
        config, _ = EmpresaConfig.objects.get_or_create(pk=1)
        config.onboarding_concluido = True
        config.documento = ''
        config.tipo_documento = ''
        config.save()
        return config

    def test_endereco_continua_exigindo_documento(self, client_autenticado, legado):
        """A cobrança do documento segue valendo para o resto do cadastro."""
        response = client_autenticado.patch(
            '/api/empresa/config/',
            {'cidade': 'Araras', 'endereco': 'Avenida Fábio da Silva Prado, 386', 'uf': 'SP'},
            format='json',
        )
        assert response.status_code == 400

    def test_salva_coordenada_sem_documento(self, client_autenticado, legado):
        """Única escrita isenta: o pino é o que leva o cliente até o negócio."""
        response = client_autenticado.patch(
            '/api/empresa/config/',
            {'latitude': '-22.350592', 'longitude': '-47.377324'},
            format='json',
        )
        assert response.status_code == 200

    def test_coordenada_junto_de_outro_campo_e_recusada(self, client_autenticado, legado):
        """A isenção vale só para a coordenada sozinha — senão bastaria anexar
        uma latitude a qualquer payload para furar a regra do documento."""
        response = client_autenticado.patch(
            '/api/empresa/config/',
            {'latitude': '-22.350592', 'longitude': '-47.377324', 'nome': 'Outro'},
            format='json',
        )
        assert response.status_code == 400

    def test_continua_exigindo_documento_ao_informa_lo(self, client_autenticado, legado):
        response = client_autenticado.patch(
            '/api/empresa/config/',
            {'documento': '', 'tipo_documento': ''},
            format='json',
        )
        assert response.data['code'][0] == 'documento_obrigatorio'
