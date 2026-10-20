import logging
import uuid

from django.contrib.auth.hashers import make_password
from django.db import transaction
from django.utils import timezone

from core.recuperacao import RecuperacaoSenhaBase
from core.limites import login_servicemanage

from apps_work.clientes.models import TipoObjeto
from apps_work.clientes.validators import validar_placa_br
from rest_framework.exceptions import ValidationError as DRFValidationError

from .models import CodigoRecuperacaoConsumidor, Consumidor, ObjetoConsumidor
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

        if not consumidor.ativo:
            raise ErroDeNegocio('Conta inativa. Entre em contato com o suporte.', 'conta_inativa', 401)

        return consumidor


class RecuperacaoSenhaConsumidorService(RecuperacaoSenhaBase):
    modelo_codigo = CodigoRecuperacaoConsumidor
    nome_produto = 'Service Manage'

    def _dono(self, email: str):
        return Consumidor.objects.filter(email=email.strip().lower()).first()

    def _dono_para_envio(self, email: str):
        # Conta desativada não recebe código.
        return Consumidor.objects.filter(email=email.strip().lower(), ativo=True).first()

    def _encerrar_sessoes(self, consumidor) -> None:
        # Todo token emitido antes de agora deixa de valer, inclusive access.
        consumidor.sessoes_validas_desde = timezone.now()
        consumidor.save(update_fields=['sessoes_validas_desde'])


class ObjetoConsumidorService:
    """Pets e veículos do consumidor: o que cada tipo exige e como aparece."""

    CAMPOS_OBRIGATORIOS = {
        TipoObjeto.VEICULO: ['placa', 'marca', 'modelo'],
        TipoObjeto.PET: ['nome', 'especie', 'porte'],
    }

    def cadastrar(self, consumidor, tipo: str, dados: dict) -> ObjetoConsumidor:
        if tipo not in self.CAMPOS_OBRIGATORIOS:
            raise ErroDeNegocio('Tipo inválido.', 'tipo_invalido')

        ausentes = [c for c in self.CAMPOS_OBRIGATORIOS[tipo] if not dados.get(c)]
        if ausentes:
            raise ErroDeNegocio(f"Campos obrigatórios: {', '.join(ausentes)}.", 'campos_obrigatorios')

        dados = dict(dados)
        if tipo == TipoObjeto.VEICULO:
            # A mesma validação do veículo cadastrado pelo negócio. Antes havia
            # uma cópia aqui que nunca era chamada: qualquer placa passava.
            try:
                dados['placa'] = validar_placa_br(dados['placa'])
            except DRFValidationError as e:
                raise ErroDeNegocio(str(e.detail[0]), 'placa_invalida')

        return ObjetoConsumidor.objects.create(
            consumidor=consumidor, tipo=tipo, dados=dados, nome_exibicao=self._nome_exibicao(tipo, dados),
        )

    def _nome_exibicao(self, tipo: str, dados: dict) -> str:
        if tipo == TipoObjeto.VEICULO:
            return f"{dados['marca']} {dados['modelo']} · {dados['placa']}"
        return f"{dados['nome']} ({dados['especie']})"


class FotoConsumidorService:
    """Foto de perfil do consumidor: troca e remoção.

    A imagem vai para o prefixo privado do bucket — a URL de leitura é assinada
    e expira. A logo do negócio é pública; o rosto do cliente, não.
    """

    def trocar(self, consumidor, arquivo) -> None:
        """Levanta ImagemInvalidaError para arquivo recusado; falha do provedor
        de armazenamento sobe como está (a view responde 500 sem detalhe)."""
        from apps_work.empresa.services import ArmazenamentoImagemService

        armazenamento = ArmazenamentoImagemService()
        armazenamento.validar(arquivo)
        anterior = consumidor.foto_chave
        # Chave nova a cada envio, e sempre um UUID: id sequencial no endereço
        # permitiria varrer as fotos de todo mundo por tentativa.
        consumidor.foto_chave = armazenamento.salvar(
            arquivo, prefixo=armazenamento.PREFIXO_CONSUMIDORES, chave=str(uuid.uuid4()),
        )
        consumidor.save(update_fields=['foto_chave'])
        # Só depois de gravar a nova: se o envio falhasse no meio, a antiga
        # ainda seria a válida.
        self._apagar(armazenamento, anterior)
        SincronizarClienteService().sincronizar(consumidor)

    def remover(self, consumidor) -> None:
        from apps_work.empresa.services import ArmazenamentoImagemService

        anterior = consumidor.foto_chave
        consumidor.foto_chave = ''
        consumidor.save(update_fields=['foto_chave'])
        self._apagar(ArmazenamentoImagemService(), anterior)
        SincronizarClienteService().sincronizar(consumidor)

    def _apagar(self, armazenamento, caminho: str) -> None:
        """Arquivo órfão no bucket é lixo, não falha: o cadastro já está certo,
        e não vale derrubar a requisição por isso."""
        if not caminho:
            return
        try:
            armazenamento.apagar(caminho)
        except Exception:
            logger.warning('Nao foi possivel apagar a foto anterior', exc_info=True)


class SincronizarClienteService:
    """Empurra a ficha do consumidor para os negócios em que ele está vinculado.

    O cadastro é único e vive no schema público; o `Cliente` de cada tenant é
    uma cópia. Sem esse empurrão a cópia congela no que foi gravado no dia do
    vínculo, e o negócio segue ligando para um telefone que o cliente já trocou.

    A falha de um negócio (schema removido, banco fora do ar) é registrada e
    engolida: o salvamento do perfil não pode depender de todos os tenants
    estarem de pé.
    """

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

                cliente.save(update_fields=cliente.espelhar(consumidor))
                return True
        except Exception:
            logger.warning(
                'Falha ao sincronizar cadastro do consumidor no tenant',
                extra={'schema_name': schema_name, 'consumidor_id': consumidor.pk},
                exc_info=True,
            )
            return False
