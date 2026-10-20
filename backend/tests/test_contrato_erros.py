"""Contrato único de erro: {detail, code, fields?} (issue #6)."""
from unittest.mock import MagicMock

import pytest
from django.http import Http404
from rest_framework import exceptions, serializers

from core.excecoes import ErroDeNegocio, erro, tratar_excecao


def _tratar(exc):
    return tratar_excecao(exc, {'view': MagicMock(), 'request': MagicMock()})


class TestHandler:
    def test_erro_de_negocio(self):
        resposta = _tratar(ErroDeNegocio('Convite já foi aceito.', 'convite_ja_aceito'))
        assert resposta.status_code == 400
        assert resposta.data == {'detail': 'Convite já foi aceito.', 'code': 'convite_ja_aceito'}

    def test_erro_de_negocio_com_outro_status(self):
        resposta = _tratar(ErroDeNegocio('Não encontrado.', 'x', 404))
        assert resposta.status_code == 404

    def test_erro_de_negocio_continua_sendo_value_error(self):
        assert issubclass(ErroDeNegocio, ValueError)

    def test_erro_de_campo_vai_para_fields(self):
        exc = exceptions.ValidationError({'email': ['Informe um e-mail válido.'], 'nome': ['Obrigatório.']})
        resposta = _tratar(exc)
        assert resposta.status_code == 400
        assert resposta.data == {
            'detail': 'Dados inválidos.',
            'code': 'invalido',
            'fields': {'email': ['Informe um e-mail válido.'], 'nome': ['Obrigatório.']},
        }

    def test_erro_nao_de_campo_vira_detail(self):
        resposta = _tratar(exceptions.ValidationError({'non_field_errors': ['Período inválido.']}))
        assert resposta.data['detail'] == 'Período inválido.'
        assert 'fields' not in resposta.data

    def test_detail_e_code_levantados_como_validation_error(self):
        # Como os services de agenda/kanban levantam.
        exc = exceptions.ValidationError({'detail': 'Horário ocupado.', 'code': 'conflito_horario'})
        assert _tratar(exc).data == {'detail': 'Horário ocupado.', 'code': 'conflito_horario'}

    def test_detail_e_code_embrulhados_em_lista_pelo_serializer(self):
        # Levantado no validate() de um serializer: o DRF embrulha cada valor em lista.
        class S(serializers.Serializer):
            def validate(self, attrs):
                raise serializers.ValidationError({'detail': 'Informe o CPF.', 'code': 'documento_obrigatorio'})

        s = S(data={})
        with pytest.raises(exceptions.ValidationError) as info:
            s.is_valid(raise_exception=True)
        assert _tratar(info.value).data == {'detail': 'Informe o CPF.', 'code': 'documento_obrigatorio'}

    def test_lista_de_mensagens(self):
        assert _tratar(exceptions.ValidationError(['Algo deu errado.'])).data == {
            'detail': 'Algo deu errado.', 'code': 'invalido',
        }

    @pytest.mark.parametrize('exc, status_code, code', [
        (exceptions.NotAuthenticated(), 401, 'nao_autenticado'),
        (exceptions.AuthenticationFailed('Token inválido.'), 401, 'nao_autenticado'),
        (exceptions.PermissionDenied(), 403, 'sem_permissao'),
        (exceptions.NotFound(), 404, 'nao_encontrado'),
        (Http404(), 404, 'nao_encontrado'),
        (exceptions.MethodNotAllowed('POST'), 405, 'metodo_nao_permitido'),
        (exceptions.Throttled(wait=10), 429, 'muitas_requisicoes'),
    ])
    def test_excecoes_do_drf(self, exc, status_code, code):
        resposta = _tratar(exc)
        assert resposta.status_code == status_code
        assert resposta.data['code'] == code
        assert isinstance(resposta.data['detail'], str)

    def test_erro_do_simplejwt_e_achatado(self):
        from rest_framework_simplejwt.exceptions import InvalidToken
        resposta = _tratar(InvalidToken())
        assert resposta.status_code == 401
        assert set(resposta.data) == {'detail', 'code'}
        assert resposta.data['code'] == 'token_invalido'

    def test_excecao_desconhecida_nao_e_tratada(self):
        assert _tratar(RuntimeError('bug')) is None


def test_helper_erro():
    resposta = erro('Data inválida.', status_code=400)
    assert resposta.data == {'detail': 'Data inválida.', 'code': 'invalido'}
    assert erro('x', 'meu_codigo', 404).data['code'] == 'meu_codigo'


# ---------------------------------------------------------------------------
# De ponta a ponta
# ---------------------------------------------------------------------------

@pytest.fixture
def api(patch_tenant_middleware, proprietario):
    from rest_framework.test import APIClient
    client = APIClient()
    client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
    client.force_authenticate(user=proprietario)
    return client


@pytest.mark.django_db
class TestDePontaAPonta:
    def test_sem_token_tem_code(self, patch_tenant_middleware):
        from rest_framework.test import APIClient
        client = APIClient()
        client.defaults['HTTP_HOST'] = 'test-empresa.localhost'
        resposta = client.get('/api/colaboradores/')
        assert resposta.status_code == 401
        assert resposta.json()['code'] == 'nao_autenticado'

    def test_erro_de_negocio_do_service_chega_com_code(self, api, proprietario):
        from apps_work.usuarios.models import Colaborador
        dono = Colaborador.objects.create(user=proprietario, role='proprietario')
        resposta = api.post(f'/api/colaboradores/{dono.id}/desativar/')
        assert resposta.status_code == 400
        assert resposta.json() == {
            'detail': 'O proprietário não pode ser desativado nem removido.',
            'code': 'proprietario_protegido',
        }

    def test_erro_de_campo_de_serializer(self, api):
        resposta = api.post('/api/convites/', {'email': 'nao-e-email'})
        assert resposta.status_code == 400
        corpo = resposta.json()
        assert corpo['code'] == 'invalido'
        assert 'email' in corpo['fields']

    def test_404_tem_code(self, api):
        resposta = api.get('/api/colaboradores/999999/')
        assert resposta.status_code == 404
        assert resposta.json()['code'] == 'nao_encontrado'
