import pytest
from unittest.mock import patch
from rest_framework.test import APIClient

from apps_work.empresa.models import EmpresaConfig, HorarioFuncionamento
from apps_work.kanban.models import EtapaKanban
from apps_work.usuarios.models import Colaborador

CNPJ_VALIDO = '11222333000181'
CPF_VALIDO = '52998224725'

# Concluir o onboarding exige documento — todo teste que finaliza precisa mandá-lo.
CONCLUIR_ONBOARDING = {
    'onboarding_concluido': True,
    'documento': CNPJ_VALIDO,
    'tipo_documento': 'cnpj',
}


@pytest.fixture
def client_autenticado(patch_tenant_middleware, proprietario):
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.fixture
def horario(patch_tenant_middleware):
    return HorarioFuncionamento.objects.create(dia=0, abertura='09:00', fechamento='18:00', ativo=True)


# --- EmpresaConfigView ---

@pytest.mark.django_db
class TestEmpresaConfigAPI:
    def test_get_config_retorna_200(self, client_autenticado):
        response = client_autenticado.get('/api/v1/empresa/config/')
        assert response.status_code == 200

    def test_get_config_cria_se_nao_existe(self, client_autenticado):
        assert EmpresaConfig.objects.count() == 0
        response = client_autenticado.get('/api/v1/empresa/config/')
        assert response.status_code == 200
        assert EmpresaConfig.objects.count() == 1

    def test_atualizar_config_retorna_200(self, client_autenticado):
        response = client_autenticado.patch('/api/v1/empresa/config/', {'nome': 'Minha Empresa'}, format='json')
        assert response.status_code == 200
        assert response.data['nome'] == 'Minha Empresa'

    def test_nicho_lava_rapido_define_tipo_kanban(self, client_autenticado):
        response = client_autenticado.patch('/api/v1/empresa/config/', {'nicho': 'lava_rapido'}, format='json')
        assert response.status_code == 200
        assert response.data['tipo_agenda'] == 'kanban'

    def test_nicho_banho_tosa_define_tipo_kanban(self, client_autenticado):
        response = client_autenticado.patch('/api/v1/empresa/config/', {'nicho': 'banho_tosa'}, format='json')
        assert response.status_code == 200
        assert response.data['tipo_agenda'] == 'kanban'

    def test_nicho_desconhecido_define_tipo_horario(self, client_autenticado):
        response = client_autenticado.patch('/api/v1/empresa/config/', {'nicho': 'barbearia'}, format='json')
        assert response.status_code == 200
        assert response.data['tipo_agenda'] == 'horario'

    def test_onboarding_concluido_cria_colaborador_proprietario(self, client_autenticado, usuario):
        response = client_autenticado.patch('/api/v1/empresa/config/', CONCLUIR_ONBOARDING, format='json')
        assert response.status_code == 200
        assert Colaborador.objects.filter(user=usuario).exists()

    def test_onboarding_kanban_cria_etapas_padrao(self, client_autenticado):
        client_autenticado.patch('/api/v1/empresa/config/', {'nicho': 'lava_rapido'}, format='json')
        client_autenticado.patch('/api/v1/empresa/config/', CONCLUIR_ONBOARDING, format='json')
        assert EtapaKanban.objects.count() == 3

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/v1/empresa/config/')
        assert response.status_code == 401

    def test_tipo_agenda_ignorado_quando_enviado_diretamente(self, client_autenticado):
        client_autenticado.patch('/api/v1/empresa/config/', {'nicho': 'lava_rapido'}, format='json')
        response = client_autenticado.patch('/api/v1/empresa/config/', {'tipo_agenda': 'horario'}, format='json')
        assert response.status_code == 200
        assert response.data['tipo_agenda'] == 'kanban'


# --- HorarioFuncionamentoViewSet ---

@pytest.mark.django_db
class TestHorarioFuncionamentoAPI:
    def test_listar_horarios_retorna_200(self, client_autenticado, horario):
        response = client_autenticado.get('/api/v1/empresa/horarios/')
        assert response.status_code == 200
        assert len(response.data) == 1

    def test_criar_horario_retorna_201(self, client_autenticado):
        payload = {'dia': 1, 'abertura': '09:00', 'fechamento': '18:00', 'ativo': True}
        response = client_autenticado.post('/api/v1/empresa/horarios/', payload)
        assert response.status_code == 201
        assert response.data['dia_label'] == 'Terça-feira'

    def test_criar_horario_existente_atualiza_e_retorna_200(self, client_autenticado, horario):
        payload = {'dia': 0, 'abertura': '10:00', 'fechamento': '19:00', 'ativo': True}
        response = client_autenticado.post('/api/v1/empresa/horarios/', payload)
        assert response.status_code == 200
        assert response.data['abertura'] == '10:00:00'

    def test_capacidade_aparece_na_resposta_do_horario(self, client_autenticado, horario):
        response = client_autenticado.get('/api/v1/empresa/horarios/')
        assert response.status_code == 200
        assert 'capacidade' in response.data[0]

    def test_criar_horario_com_capacidade_salva_valor(self, client_autenticado):
        payload = {'dia': 1, 'abertura': '08:00', 'fechamento': '18:00', 'ativo': True, 'capacidade': 15}
        response = client_autenticado.post('/api/v1/empresa/horarios/', payload)
        assert response.status_code == 201
        assert response.data['capacidade'] == 15

    def test_capacidade_aceita_null(self, client_autenticado):
        payload = {'dia': 2, 'abertura': '08:00', 'fechamento': '18:00', 'ativo': True, 'capacidade': None}
        response = client_autenticado.post('/api/v1/empresa/horarios/', payload, format='json')
        assert response.status_code == 201
        assert response.data['capacidade'] is None

    def test_capacidade_zero_retorna_erro(self, client_autenticado):
        payload = {'dia': 3, 'abertura': '08:00', 'fechamento': '18:00', 'ativo': True, 'capacidade': 0}
        response = client_autenticado.post('/api/v1/empresa/horarios/', payload)
        assert response.status_code == 400

    def test_capacidade_negativa_retorna_erro(self, client_autenticado):
        payload = {'dia': 4, 'abertura': '08:00', 'fechamento': '18:00', 'ativo': True, 'capacidade': -5}
        response = client_autenticado.post('/api/v1/empresa/horarios/', payload)
        assert response.status_code == 400

    def test_capacidade_preservada_ao_atualizar_horario(self, client_autenticado):
        client_autenticado.post('/api/v1/empresa/horarios/', {'dia': 5, 'abertura': '08:00', 'fechamento': '14:00', 'ativo': True, 'capacidade': 8}, format='json')
        response = client_autenticado.post('/api/v1/empresa/horarios/', {'dia': 5, 'abertura': '09:00', 'fechamento': '14:00', 'ativo': True, 'capacidade': 8}, format='json')
        assert response.status_code == 200
        assert response.data['capacidade'] == 8

    def test_sem_autenticacao_retorna_401(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get('/api/v1/empresa/horarios/')
        assert response.status_code == 401


@pytest.mark.django_db
class TestEmpresaModelsStr:
    def test_str_empresa_config_com_nome(self, patch_tenant_middleware):
        config = EmpresaConfig.objects.create(nome='Barbearia Estilo')
        assert str(config) == 'Barbearia Estilo'

    def test_str_empresa_config_sem_nome_retorna_fallback(self, patch_tenant_middleware):
        config = EmpresaConfig.objects.create(nome='')
        assert str(config) == 'Empresa sem nome'

    def test_str_horario_funcionamento(self, patch_tenant_middleware):
        horario = HorarioFuncionamento.objects.create(dia=0, abertura='09:00', fechamento='18:00', ativo=True)
        assert str(horario) == 'Segunda-feira'


@pytest.mark.django_db
class TestEmpresaConfigExcecoesSilenciadas:
    def test_excecao_em_criar_colaborador_nao_interrompe_onboarding(self, client_autenticado):
        with patch('apps_work.usuarios.models.Colaborador.objects.get_or_create', side_effect=RuntimeError('db error')):
            response = client_autenticado.patch(
                '/api/v1/empresa/config/', CONCLUIR_ONBOARDING, format='json'
            )
        assert response.status_code == 200

    def test_excecao_em_etapas_kanban_nao_interrompe_onboarding(self, client_autenticado):
        client_autenticado.patch('/api/v1/empresa/config/', {'nicho': 'lava_rapido'}, format='json')
        with patch('apps_work.kanban.services.EtapaService.criar_etapas_padrao', side_effect=RuntimeError('service error')):
            response = client_autenticado.patch(
                '/api/v1/empresa/config/', CONCLUIR_ONBOARDING, format='json'
            )
        assert response.status_code == 200


# --- Localização: pino manual x geocodificador automático ---

GEOCODIFICAR = 'apps_work.empresa.services.GeocodificacaoService.geocodificar'


@pytest.mark.django_db
class TestLocalizacaoEmpresa:
    def test_endereco_novo_dispara_geocodificacao(self, client_autenticado):
        with patch(GEOCODIFICAR, return_value=('-22.340747', '-47.370182')) as geo:
            client_autenticado.patch(
                '/api/v1/empresa/config/',
                {'endereco': 'Avenida Fábio da Silva Prado, 386', 'cidade': 'Araras', 'uf': 'SP'},
                format='json',
            )
        assert geo.called
        config = EmpresaConfig.objects.get(pk=1)
        assert str(config.latitude) == '-22.340747'
        assert config.localizacao_confirmada is False

    def test_uf_e_repassada_ao_geocodificador(self, client_autenticado):
        """Sem a UF a busca depende de 'cidade + Brasil' desambiguar sozinha, e
        existe mais de uma Araras no país."""
        with patch(GEOCODIFICAR, return_value=None) as geo:
            client_autenticado.patch(
                '/api/v1/empresa/config/',
                {'endereco': 'Rua Um, 10', 'cidade': 'Araras', 'uf': 'SP'},
                format='json',
            )
        assert geo.call_args.args == ('Rua Um, 10', 'Araras', 'SP')

    def test_coordenada_enviada_marca_localizacao_confirmada(self, client_autenticado):
        response = client_autenticado.patch(
            '/api/v1/empresa/config/',
            {'latitude': '-22.350592', 'longitude': '-47.377324'},
            format='json',
        )
        assert response.status_code == 200
        assert response.data['localizacao_confirmada'] is True

    def test_pino_confirmado_nao_e_sobrescrito_por_novo_endereco(self, client_autenticado):
        """O geocodificador não pode apagar uma coordenada apontada à mão —
        nenhum serviço gratuito acerta o número no Brasil."""
        client_autenticado.patch(
            '/api/v1/empresa/config/',
            {'latitude': '-22.350592', 'longitude': '-47.377324'},
            format='json',
        )

        with patch(GEOCODIFICAR, return_value=('-1.000000', '-1.000000')) as geo:
            client_autenticado.patch(
                '/api/v1/empresa/config/',
                {'endereco': 'Outro endereço, 999', 'cidade': 'Araras'},
                format='json',
            )

        assert not geo.called
        config = EmpresaConfig.objects.get(pk=1)
        assert str(config.latitude) == '-22.350592'
        assert str(config.longitude) == '-47.377324'

    def test_localizacao_confirmada_nao_e_gravavel_pelo_payload(self, client_autenticado):
        """Só apontar o ponto no mapa confirma a localização. Aceitar a flag
        direto deixaria travar o geocodificador sem nunca ter marcado nada."""
        response = client_autenticado.patch(
            '/api/v1/empresa/config/', {'localizacao_confirmada': True}, format='json'
        )
        assert response.status_code == 200
        assert EmpresaConfig.objects.get(pk=1).localizacao_confirmada is False

    def test_cep_e_uf_sao_normalizados(self, client_autenticado):
        response = client_autenticado.patch(
            '/api/v1/empresa/config/', {'cep': '13604-512', 'uf': 'sp'}, format='json'
        )
        assert response.status_code == 200
        assert response.data['cep'] == '13604512'
        assert response.data['uf'] == 'SP'


# --- GeocodificarView: palpite de coordenada para endereço não salvo ---

@pytest.mark.django_db
class TestGeocodificarAPI:
    URL = '/api/v1/empresa/geocodificar/'

    def test_exige_autenticacao(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get(self.URL, {'cidade': 'Araras'})
        assert response.status_code == 401

    def test_sem_endereco_nem_cidade_retorna_400(self, client_autenticado):
        response = client_autenticado.get(self.URL)
        assert response.status_code == 400

    def test_devolve_a_coordenada_do_geocodificador(self, client_autenticado):
        with patch(GEOCODIFICAR, return_value=('-22.340747', '-47.370182')):
            response = client_autenticado.get(
                self.URL, {'endereco': 'Avenida Fábio da Silva Prado, 386', 'cidade': 'Araras', 'uf': 'SP'}
            )
        assert response.data == {'latitude': '-22.340747', 'longitude': '-47.370182'}

    def test_endereco_nao_encontrado_devolve_nulo_e_nao_erro(self, client_autenticado):
        """Sem palpite o mapa cai no próximo passo da cascata. Devolver erro
        travaria o cadastro por causa do mapa, que é pior que coordenada ruim."""
        with patch(GEOCODIFICAR, return_value=None):
            response = client_autenticado.get(self.URL, {'cidade': 'Lugar Nenhum'})
        assert response.status_code == 200
        assert response.data == {'latitude': None, 'longitude': None}

    def test_coordenada_sai_no_formato_do_empresa_config(self, client_autenticado):
        """O Nominatim devolve até 7 casas; a config guarda 6. O palpite já
        sai no formato que o PATCH da config aceita."""
        with patch(GEOCODIFICAR, return_value=('-22.3407471', '-47.3701829')):
            response = client_autenticado.get(self.URL, {'cidade': 'Araras'})
        assert response.data == {'latitude': '-22.340747', 'longitude': '-47.370183'}

    def test_falha_do_geocodificador_nao_derruba_a_requisicao(self, client_autenticado):
        with patch(GEOCODIFICAR, side_effect=RuntimeError('nominatim fora do ar')):
            response = client_autenticado.get(self.URL, {'cidade': 'Araras'})
        assert response.status_code == 200
        assert response.data == {'latitude': None, 'longitude': None}


# --- RuaNoPontoView: conferência visual de que o pino caiu na rua certa ---

RUA_NO_PONTO = 'apps_work.empresa.services.GeocodificacaoService.rua_no_ponto'


@pytest.mark.django_db
class TestRuaNoPontoAPI:
    URL = '/api/v1/empresa/rua-no-ponto/'

    def test_exige_autenticacao(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.get(self.URL, {'lat': '-22.35', 'lng': '-47.37'})
        assert response.status_code == 401

    def test_devolve_o_nome_da_via(self, client_autenticado):
        with patch(RUA_NO_PONTO, return_value='Avenida Fábio da Silva Prado'):
            response = client_autenticado.get(self.URL, {'lat': '-22.350592', 'lng': '-47.377324'})
        assert response.data == {'rua': 'Avenida Fábio da Silva Prado'}

    def test_coordenada_nao_numerica_retorna_400(self, client_autenticado):
        response = client_autenticado.get(self.URL, {'lat': 'abc', 'lng': '-47.37'})
        assert response.status_code == 400

    def test_coordenada_fora_dos_limites_retorna_400(self, client_autenticado):
        response = client_autenticado.get(self.URL, {'lat': '-999', 'lng': '-47.37'})
        assert response.status_code == 400

    def test_via_desconhecida_devolve_nulo_e_nao_erro(self, client_autenticado):
        """Sem rua o rótulo some da tela — não pode virar erro que assuste o dono."""
        with patch(RUA_NO_PONTO, return_value=None):
            response = client_autenticado.get(self.URL, {'lat': '-22.35', 'lng': '-47.37'})
        assert response.status_code == 200
        assert response.data == {'rua': None}

    def test_falha_do_nominatim_nao_derruba_a_requisicao(self, client_autenticado):
        with patch(RUA_NO_PONTO, side_effect=RuntimeError('nominatim fora do ar')):
            response = client_autenticado.get(self.URL, {'lat': '-22.35', 'lng': '-47.37'})
        assert response.status_code == 200
        assert response.data == {'rua': None}


# --- Upload da logo ---

SALVAR_LOGO = 'apps_work.empresa.services.ArmazenamentoImagemService.salvar'
URL_LOGO = 'apps_work.empresa.services.ArmazenamentoImagemService.url'


def _imagem(nome='logo.png', tipo='image/png', tamanho=1024):
    """Arquivo qualquer — serve para os testes que não chegam a abrir a imagem."""
    from django.core.files.uploadedfile import SimpleUploadedFile
    return SimpleUploadedFile(nome, b'x' * tamanho, content_type=tipo)


def _imagem_png(nome='logo.png', lado=800):
    """PNG de verdade, para os testes que passam pelo Pillow."""
    from io import BytesIO

    from django.core.files.uploadedfile import SimpleUploadedFile
    from PIL import Image

    buffer = BytesIO()
    Image.new('RGB', (lado, lado), 'red').save(buffer, format='PNG')
    return SimpleUploadedFile(nome, buffer.getvalue(), content_type='image/png')


@pytest.mark.django_db
class TestUploadLogoAPI:
    URL = '/api/v1/empresa/config/logo/'

    def test_exige_autenticacao(self, patch_tenant_middleware):
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        response = client.post(self.URL, {'logo': _imagem()}, format='multipart')
        assert response.status_code == 401

    def test_sem_arquivo_retorna_400(self, client_autenticado):
        response = client_autenticado.post(self.URL, {}, format='multipart')
        assert response.status_code == 400

    def test_arquivo_acima_de_5mb_e_recusado(self, client_autenticado):
        grande = _imagem(tamanho=5 * 1024 * 1024 + 1)
        response = client_autenticado.post(self.URL, {'logo': grande}, format='multipart')
        assert response.status_code == 400

    def test_arquivo_que_nao_e_imagem_e_recusado(self, client_autenticado):
        pdf = _imagem(nome='contrato.pdf', tipo='application/pdf')
        response = client_autenticado.post(self.URL, {'logo': pdf}, format='multipart')
        assert response.status_code == 400

    def test_upload_valido_grava_a_url_na_config(self, client_autenticado):
        with patch(SALVAR_LOGO, return_value='logos/x.webp'),              patch(URL_LOGO, return_value='https://cdn.exemplo/logos/x.webp'):
            response = client_autenticado.post(self.URL, {'logo': _imagem()}, format='multipart')
        assert response.status_code == 200
        assert EmpresaConfig.objects.get(pk=1).logo_url == 'https://cdn.exemplo/logos/x.webp'

    def test_chave_no_bucket_segue_o_padrao(self, client_autenticado):
        """Trava o endereço das imagens.

        A chave é determinística — um arquivo por tenant, sobrescrito. Se ela
        mudar, as logos publicadas viram órfãs e o estrago só aparece no mapa do
        app do cliente, não numa exceção."""
        from django.db import connection

        with patch('apps_work.empresa.services.default_storage') as storage:
            storage.url.return_value = 'https://bucket/logos/x.webp'
            client_autenticado.post(self.URL, {'logo': _imagem_png()}, format='multipart')

        assert storage.save.call_args.args[0] == f'logos/{connection.schema_name}.webp'

    def test_imagem_e_reduzida_e_convertida_para_webp(self):
        """O redimensionamento saiu do Cloudinary e passou a ser nosso."""
        from io import BytesIO

        from PIL import Image

        from apps_work.empresa.services import ArmazenamentoImagemService

        with patch('apps_work.empresa.services.default_storage') as storage:
            ArmazenamentoImagemService().salvar(
                _imagem_png(lado=800),
                prefixo=ArmazenamentoImagemService.PREFIXO_LOGOS,
                chave='ponto_w',
            )

        enviado = Image.open(BytesIO(storage.save.call_args.args[1].read()))
        assert enviado.format == 'WEBP'
        assert max(enviado.size) == ArmazenamentoImagemService.LADO_MAXIMO

    def test_falha_do_provedor_nao_vaza_detalhe_de_infraestrutura(self, client_autenticado):
        """A exceção do provedor pode carregar host, chave ou payload — ela vai
        para o log, nunca para a resposta."""
        segredo = 'aws SignatureDoesNotMatch api_key=123456'
        with patch(SALVAR_LOGO, side_effect=RuntimeError(segredo)):
            response = client_autenticado.post(self.URL, {'logo': _imagem()}, format='multipart')
        assert response.status_code == 503
        assert response.data['code'] == 'armazenamento_indisponivel'
        assert 'api_key' not in str(response.data)
