import logging

from django.contrib.auth.hashers import make_password
from django.db import transaction
from django.utils import timezone

from core.recuperacao import RecuperacaoSenhaBase
from core.limites import login_servicemanage

from .models import CodigoRecuperacaoConsumidor, Consumidor
from core.excecoes import ErroDeNegocio

logger = logging.getLogger(__name__)


class RegistroConsumidorService:
    def registrar(self, nome: str, email: str, senha: str, telefone: str = '') -> Consumidor:
        email = email.strip().lower()

        if Consumidor.objects.filter(email=email).exists():
            raise ErroDeNegocio('Já existe uma conta com este e-mail.', 'email_ja_cadastrado')

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
            raise ErroDeNegocio('E-mail ou senha inválidos.', 'credenciais_invalidas', 401)
        login_servicemanage.limpar(email)

        if not consumidor.is_active:
            raise ErroDeNegocio('Conta inativa. Entre em contato com o suporte.', 'conta_inativa', 401)

        return consumidor


class RecuperacaoSenhaConsumidorService(RecuperacaoSenhaBase):
    modelo_codigo = CodigoRecuperacaoConsumidor
    nome_produto = 'Service Manage'

    def _dono(self, email: str):
        return Consumidor.objects.filter(email=email.strip().lower()).first()

    def _dono_para_envio(self, email: str):
        # Conta desativada não recebe código.
        return Consumidor.objects.filter(email=email.strip().lower(), is_active=True).first()

    def _encerrar_sessoes(self, consumidor) -> None:
        # Todo token emitido antes de agora deixa de valer, inclusive access.
        consumidor.sessoes_validas_desde = timezone.now()
        consumidor.save(update_fields=['sessoes_validas_desde'])


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
