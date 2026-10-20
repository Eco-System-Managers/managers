import re
import pytest
from decimal import Decimal
from datetime import timedelta
from unittest.mock import patch

from django.utils import timezone

from apps_serv.consumidores.models import Consumidor, CodigoRecuperacaoConsumidor
from apps_serv.consumidores.services import (
    LoginConsumidorService,
    RecuperacaoSenhaConsumidorService,
    RegistroConsumidorService,
)


@pytest.fixture
def consumidor_registrado(db):
    return RegistroConsumidorService().registrar(
        nome='João Silva',
        email='joao@teste.com',
        senha='SenhaForte123!',
    )


@pytest.mark.django_db
class TestRegistroConsumidorService:
    def test_registrar_cria_consumidor_com_nome_e_email(self, db):
        consumidor = RegistroConsumidorService().registrar(
            nome='Ana Lima', email='ana@teste.com', senha='SenhaForte123!',
        )
        assert consumidor.id is not None
        assert consumidor.nome == 'Ana Lima'
        assert consumidor.email == 'ana@teste.com'
        assert Consumidor.objects.filter(id=consumidor.id).exists()

    def test_registrar_email_duplicado_levanta_value_error(self, consumidor_registrado):
        with pytest.raises(ValueError, match='e-mail'):
            RegistroConsumidorService().registrar(
                nome='Outro', email='joao@teste.com', senha='SenhaForte123!',
            )

    def test_registrar_normaliza_email_para_lowercase(self, db):
        consumidor = RegistroConsumidorService().registrar(
            nome='Pedro', email='Pedro@TESTE.COM', senha='SenhaForte123!',
        )
        assert consumidor.email == 'pedro@teste.com'

    def test_registrar_salva_senha_com_hash(self, db):
        consumidor = RegistroConsumidorService().registrar(
            nome='Carlos', email='carlos@teste.com', senha='SenhaForte123!',
        )
        assert consumidor.check_password('SenhaForte123!')
        assert consumidor.password != 'SenhaForte123!'


@pytest.mark.django_db
class TestLoginConsumidorService:
    def test_autenticar_credenciais_corretas_retorna_consumidor(self, consumidor_registrado):
        consumidor = LoginConsumidorService().autenticar(
            email='joao@teste.com', senha='SenhaForte123!',
        )
        assert consumidor.id == consumidor_registrado.id

    def test_autenticar_normaliza_email_para_lowercase(self, consumidor_registrado):
        consumidor = LoginConsumidorService().autenticar(
            email='JOAO@TESTE.COM', senha='SenhaForte123!',
        )
        assert consumidor.id == consumidor_registrado.id

    def test_autenticar_senha_errada_levanta_value_error(self, consumidor_registrado):
        with pytest.raises(ValueError, match='inválidos'):
            LoginConsumidorService().autenticar(email='joao@teste.com', senha='errada')

    def test_autenticar_email_inexistente_levanta_value_error(self, db):
        with pytest.raises(ValueError, match='inválidos'):
            LoginConsumidorService().autenticar(email='nao@existe.com', senha='qualquer')

    def test_autenticar_usuario_inativo_levanta_value_error(self, consumidor_registrado):
        consumidor_registrado.ativo = False
        consumidor_registrado.save()
        with pytest.raises(ValueError, match='inativa'):
            LoginConsumidorService().autenticar(email='joao@teste.com', senha='SenhaForte123!')


@pytest.mark.django_db
class TestRecuperacaoSenhaConsumidorService:
    def test_solicitar_cria_codigo_de_8_digitos(self, consumidor_registrado):
        with patch('core.email.send_mail') as mock_mail:
            RecuperacaoSenhaConsumidorService().solicitar(consumidor_registrado.email)
        registro = CodigoRecuperacaoConsumidor.objects.filter(
            consumidor=consumidor_registrado, usado=False
        ).first()
        assert registro is not None
        codigo = re.search(r'\b(\d+)\b', mock_mail.call_args.kwargs['message']).group(1)
        assert len(codigo) == 8
        assert registro.confere(codigo)
        # Só o hash fica no banco.
        assert codigo not in registro.codigo_hash

    def test_solicitar_invalida_codigos_anteriores(self, consumidor_registrado):
        antigo, _ = CodigoRecuperacaoConsumidor.emitir(consumidor_registrado, '11111111')
        with patch('core.email.send_mail'):
            RecuperacaoSenhaConsumidorService().solicitar(consumidor_registrado.email)
        antigo.refresh_from_db()
        assert antigo.usado is True

    def test_verificar_codigo_correto_retorna_true(self, consumidor_registrado):
        CodigoRecuperacaoConsumidor.emitir(consumidor_registrado, '12345678')[0]
        resultado = RecuperacaoSenhaConsumidorService().verificar_codigo(
            consumidor_registrado.email, '12345678'
        )
        assert resultado is True

    def test_verificar_codigo_errado_retorna_false_e_incrementa_tentativas(self, consumidor_registrado):
        registro = CodigoRecuperacaoConsumidor.emitir(consumidor_registrado, '12345678')[0]
        resultado = RecuperacaoSenhaConsumidorService().verificar_codigo(
            consumidor_registrado.email, '00000000'
        )
        assert resultado is False
        registro.refresh_from_db()
        assert registro.tentativas == 1

    def test_verificar_codigo_bloqueado_apos_5_tentativas(self, consumidor_registrado):
        registro, _ = CodigoRecuperacaoConsumidor.emitir(consumidor_registrado, '12345678')
        registro.tentativas = 5
        registro.save()
        resultado = RecuperacaoSenhaConsumidorService().verificar_codigo(
            consumidor_registrado.email, '12345678'
        )
        assert resultado is False

    def test_verificar_codigo_expirado_retorna_false(self, consumidor_registrado):
        registro = CodigoRecuperacaoConsumidor.emitir(consumidor_registrado, '12345678')[0]
        registro.expira_em = timezone.now() - timedelta(minutes=1)
        registro.save()
        resultado = RecuperacaoSenhaConsumidorService().verificar_codigo(
            consumidor_registrado.email, '12345678'
        )
        assert resultado is False

    def test_redefinir_senha_atualiza_password_e_marca_codigo_usado(self, consumidor_registrado):
        registro, _ = CodigoRecuperacaoConsumidor.emitir(consumidor_registrado, '12345678')
        RecuperacaoSenhaConsumidorService().redefinir_senha(
            consumidor_registrado.email, '12345678', 'NovaSenha456!'
        )
        consumidor_registrado.refresh_from_db()
        assert consumidor_registrado.check_password('NovaSenha456!')
        registro.refresh_from_db()
        assert registro.usado is True

    def test_redefinir_senha_com_codigo_errado_levanta_value_error(self, consumidor_registrado):
        CodigoRecuperacaoConsumidor.emitir(consumidor_registrado, '12345678')[0]
        with pytest.raises(ValueError, match='inválido'):
            RecuperacaoSenhaConsumidorService().redefinir_senha(
                consumidor_registrado.email, '00000000', 'NovaSenha456!'
            )
