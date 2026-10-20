import logging

from django.contrib.auth.hashers import make_password
from django.db import transaction
from django.utils import timezone

from core.email import enviar_email
from core.limites import login_servicemanage

from .models import CodigoRecuperacaoConsumidor, Consumidor

logger = logging.getLogger(__name__)


class RegistroConsumidorService:
    def registrar(self, nome: str, email: str, senha: str, telefone: str = '') -> Consumidor:
        email = email.strip().lower()

        if Consumidor.objects.filter(email=email).exists():
            raise ValueError('Já existe uma conta com este e-mail.')

        with transaction.atomic():
            consumidor = Consumidor(nome=nome, email=email, telefone=telefone)
            consumidor.set_password(senha)
            consumidor.save()

        return consumidor


class LoginConsumidorService:
    def autenticar(self, email: str, senha: str) -> Consumidor:
        email = email.strip().lower()
        # Levanta MuitasTentativas com 10 falhas em 15 minutos para o e-mail.
        login_servicemanage.verificar(email)

        consumidor = Consumidor.objects.filter(email=email).first()
        if consumidor is None:
            # Calcula um hash mesmo assim: sem isso, e-mail inexistente responde
            # mais rápido e o tempo de resposta revela quem tem conta.
            make_password(senha)
        if consumidor is None or not consumidor.check_password(senha):
            login_servicemanage.registrar_falha(email)
            raise ValueError('E-mail ou senha inválidos.')
        login_servicemanage.limpar(email)

        if not consumidor.is_active:
            raise ValueError('Conta inativa. Entre em contato com o suporte.')

        return consumidor


class RecuperacaoSenhaConsumidorService:
    GENERIC_MSG = 'Se este e-mail estiver cadastrado, você receberá um código em instantes.'

    def solicitar(self, email: str) -> str:
        try:
            consumidor = Consumidor.objects.get(email=email.strip().lower(), is_active=True)
        except Consumidor.DoesNotExist:
            return self.GENERIC_MSG

        _, codigo = CodigoRecuperacaoConsumidor.emitir(consumidor)
        enviar_email.enqueue(
            assunto='Código de recuperação — Service Manage',
            mensagem=f'Seu código de recuperação é: {codigo}\n\nEle expira em 15 minutos.',
            destinatario=consumidor.email,
        )

        return self.GENERIC_MSG

    def _codigo_vigente(self, consumidor):
        registro = CodigoRecuperacaoConsumidor.objects.filter(
            consumidor=consumidor, usado=False
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

    def verificar_codigo(self, email: str, codigo: str) -> bool:
        try:
            consumidor = Consumidor.objects.get(email=email.strip().lower())
        except Consumidor.DoesNotExist:
            return False

        registro = self._codigo_vigente(consumidor)
        return registro is not None and self._conferir(registro, codigo)

    def redefinir_senha(self, email: str, codigo: str, nova_senha: str) -> None:
        try:
            consumidor = Consumidor.objects.get(email=email.strip().lower())
        except Consumidor.DoesNotExist:
            raise ValueError('Código inválido.')

        registro = self._codigo_vigente(consumidor)
        if registro is None or not self._conferir(registro, codigo):
            raise ValueError('Código inválido ou expirado.')

        consumidor.set_password(nova_senha)
        # Derruba todas as sessões abertas: quem pediu a recuperação pode
        # estar tirando um invasor da conta.
        consumidor.sessoes_validas_desde = timezone.now()
        consumidor.save(update_fields=['password', 'sessoes_validas_desde'])
        registro.usado = True
        registro.save(update_fields=['usado'])


class SincronizarClienteService:
    """Empurra a ficha do consumidor para os negócios em que ele está vinculado.

    O cadastro é único e vive no schema público; o `Cliente` de cada tenant é
    uma cópia. Sem esse empurrão a cópia congela no que foi gravado no dia do
    vínculo, e o negócio segue ligando para um telefone que o cliente já trocou.

    A falha de um negócio (schema removido, banco fora do ar) é registrada e
    engolida: o salvamento do perfil não pode depender de todos os tenants
    estarem de pé.
    """

    # `foto_chave` entra aqui e não como caso especial: para o negócio, a foto é
    # mais um dado da ficha do cliente. Some junto quando o vínculo é desfeito.
    CAMPOS = [
        'nome', 'telefone', 'cpf', 'data_nascimento',
        'cep', 'endereco', 'numero_endereco', 'foto_chave',
    ]

    def sincronizar(self, consumidor: Consumidor) -> int:
        from .models import VinculoConsumidor

        schemas = VinculoConsumidor.objects.filter(
            consumidor=consumidor, ativo=True,
        ).values_list('schema_name', flat=True)

        sincronizados = 0
        for schema_name in schemas:
            if self._sincronizar_um(consumidor, schema_name):
                sincronizados += 1
        return sincronizados

    def _sincronizar_um(self, consumidor: Consumidor, schema_name: str) -> bool:
        from django_tenants.utils import schema_context

        try:
            with schema_context(schema_name):
                from apps_serv.identidade import cliente_do_consumidor

                cliente = cliente_do_consumidor(consumidor)
                if cliente is None:
                    return False

                for campo in self.CAMPOS:
                    setattr(cliente, campo, getattr(consumidor, campo))
                cliente.save(update_fields=self.CAMPOS)
                return True
        except Exception:
            logger.warning(
                'Falha ao sincronizar cadastro do consumidor no tenant',
                extra={'schema_name': schema_name, 'consumidor_id': consumidor.pk},
                exc_info=True,
            )
            return False
