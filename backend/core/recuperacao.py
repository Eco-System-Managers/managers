from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError

from core.email import enviar_email
from core.excecoes import ErroDeNegocio


class RecuperacaoSenhaBase:
    """Fluxo de recuperação de senha por código, comum aos dois produtos.

    Cada produto informa o model do código (subclasse de
    `core.models.CodigoRecuperacaoBase`), como achar o dono da conta pelo
    e-mail e como derrubar as sessões dele depois da troca.
    """

    GENERIC_MSG = 'Se este e-mail estiver cadastrado, você receberá um código em instantes.'
    modelo_codigo = None
    nome_produto = ''

    def _dono(self, email: str):
        raise NotImplementedError

    def _dono_para_envio(self, email: str):
        """Quem pode receber um código. Por padrão, o mesmo de `_dono`."""
        return self._dono(email)

    def _encerrar_sessoes(self, dono) -> None:
        raise NotImplementedError

    def _codigo_vigente(self, dono):
        if dono is None:
            return None
        registro = self.modelo_codigo.objects.filter(
            **{self.modelo_codigo.CAMPO_DONO: dono, 'usado': False},
        ).first()
        if registro is None or registro.expirado or registro.bloqueado:
            return None
        return registro

    def _conferir(self, registro, codigo: str) -> bool:
        if registro.confere(codigo):
            return True
        registro.tentativas += 1
        registro.save(update_fields=['tentativas'])
        return False

    def solicitar(self, email: str) -> str:
        """Envia um código novo. Responde igual exista ou não a conta."""
        dono = self._dono_para_envio(email)
        if dono is None:
            return self.GENERIC_MSG

        _, codigo = self.modelo_codigo.emitir(dono)
        enviar_email.enqueue(
            assunto=f'Código de recuperação — {self.nome_produto}',
            mensagem=f'Seu código de recuperação é: {codigo}\n\nEle expira em 15 minutos.',
            destinatario=dono.email,
        )
        return self.GENERIC_MSG

    def verificar_codigo(self, email: str, codigo: str) -> bool:
        registro = self._codigo_vigente(self._dono(email))
        return registro is not None and self._conferir(registro, codigo)

    def redefinir_senha(self, email: str, codigo: str, nova_senha: str) -> None:
        # Sem transação: a tentativa errada precisa ficar gravada mesmo com o
        # erro — senão o limite de tentativas nunca seria atingido.
        dono = self._dono(email)

        # Com o dono, para a regra de "senha parecida com o e-mail" valer; e
        # antes do código, para senha fraca não gastar uma tentativa.
        try:
            validate_password(nova_senha, dono)
        except DjangoValidationError as e:
            raise ErroDeNegocio(' '.join(e.messages), 'senha_fraca')

        registro = self._codigo_vigente(dono)
        if registro is None or not self._conferir(registro, codigo):
            raise ErroDeNegocio('Código inválido ou expirado.', 'codigo_invalido')

        dono.set_password(nova_senha)
        dono.save(update_fields=['password'])
        registro.usado = True
        registro.save(update_fields=['usado'])
        # Quem pediu a recuperação pode estar tirando um invasor da conta.
        self._encerrar_sessoes(dono)
