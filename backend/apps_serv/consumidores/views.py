import logging
import re
import uuid

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.utils import OpenApiParameter, extend_schema

from apps_serv.autenticacao.authentication import ConsumidorJWTAuthentication
from .models import AgendamentoConsumidor, ObjetoConsumidor, VinculoConsumidor
from .services import SincronizarClienteService
from .serializers import (
    AgendamentoConsumidorSerializer,
    CancelamentoAgendamentoSerializer,
    ConsumidorSerializer,
    ConsumidorUpdateSerializer,
    FotoPerfilUploadSerializer,
    ObjetoConsumidorSerializer,
    VinculoNegocioSerializer,
)
from core.excecoes import erro
from core.paginacao import Paginacao, resposta_paginada
from apps_work.clientes.models import TipoObjeto

logger = logging.getLogger(__name__)


class MeuPerfilView(APIView):
    authentication_classes = [ConsumidorJWTAuthentication]
    permission_classes = [IsAuthenticated]

    @extend_schema(responses=ConsumidorSerializer, summary='Meu cadastro')
    def get(self, request):
        return Response(ConsumidorSerializer(request.user).data)

    @extend_schema(
        request=ConsumidorUpdateSerializer, responses=ConsumidorSerializer,
        summary='Editar meu cadastro (e-mail não muda por aqui)',
    )
    def patch(self, request):
        serializer = ConsumidorUpdateSerializer(request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        consumidor = serializer.save()

        # O cadastro e unico: os negocios vinculados guardam copia, e ela
        # precisa acompanhar. Falha de tenant nao derruba o salvamento.
        SincronizarClienteService().sincronizar(consumidor)

        return Response(ConsumidorSerializer(consumidor).data)


class FotoPerfilView(APIView):
    """Foto do consumidor: envio e remoção.

    A imagem vai para o prefixo privado do bucket — a URL de leitura é assinada
    e expira. Diferente da logo do negócio, que é pública porque aparece no mapa
    para qualquer pessoa, o rosto do cliente só é visto por quem tem o endereço
    assinado no momento.
    """

    authentication_classes = [ConsumidorJWTAuthentication]
    permission_classes = [IsAuthenticated]

    @extend_schema(
        request={'multipart/form-data': FotoPerfilUploadSerializer}, responses=ConsumidorSerializer,
        summary='Enviar foto de perfil',
    )
    def post(self, request):
        from apps_work.empresa.services import ArmazenamentoImagemService, ImagemInvalidaError

        arquivo = request.FILES.get('foto')
        if not arquivo:
            return erro('Nenhum arquivo enviado.', status_code=status.HTTP_400_BAD_REQUEST)

        servico = ArmazenamentoImagemService()
        try:
            servico.validar(arquivo)
        except ImagemInvalidaError as e:
            return erro(str(e), getattr(e, 'code', None), status.HTTP_400_BAD_REQUEST)

        consumidor = request.user
        anterior = consumidor.foto_chave

        try:
            # Chave nova a cada envio, e sempre um UUID: id sequencial no
            # endereço permitiria varrer as fotos de todo mundo por tentativa.
            caminho = servico.salvar(
                arquivo,
                prefixo=servico.PREFIXO_CONSUMIDORES,
                chave=str(uuid.uuid4()),
            )
        except Exception:
            logger.exception('Falha ao enviar a foto do consumidor', extra={'consumidor_id': consumidor.id})
            return erro('Não foi possível enviar a imagem. Tente novamente.', status_code=status.HTTP_500_INTERNAL_SERVER_ERROR)

        consumidor.foto_chave = caminho
        consumidor.save(update_fields=['foto_chave'])

        # Só depois de gravar a nova: se o upload falhasse no meio, a antiga
        # ainda seria a válida.
        self._apagar(servico, anterior)

        SincronizarClienteService().sincronizar(consumidor)

        return Response(ConsumidorSerializer(consumidor).data)

    @extend_schema(request=None, responses=ConsumidorSerializer, summary='Remover foto de perfil')
    def delete(self, request):
        from apps_work.empresa.services import ArmazenamentoImagemService

        consumidor = request.user
        anterior = consumidor.foto_chave

        consumidor.foto_chave = ''
        consumidor.save(update_fields=['foto_chave'])

        self._apagar(ArmazenamentoImagemService(), anterior)
        SincronizarClienteService().sincronizar(consumidor)

        return Response(ConsumidorSerializer(consumidor).data)

    def _apagar(self, servico, caminho: str) -> None:
        """Arquivo órfão no bucket é lixo, não falha: se a remoção não der
        certo, o cadastro já está correto e não vale derrubar a requisição."""
        if not caminho:
            return
        try:
            servico.apagar(caminho)
        except Exception:
            logger.warning('Nao foi possivel apagar a foto anterior', exc_info=True)


class MeusAgendamentosView(APIView):
    authentication_classes = [ConsumidorJWTAuthentication]
    permission_classes = [IsAuthenticated]
    pagination_class = Paginacao

    @extend_schema(
        responses=AgendamentoConsumidorSerializer(many=True),
        parameters=[OpenApiParameter('status', str, description='Filtra pelo status do agendamento.')],
        summary='Minha agenda, em todos os negócios',
    )
    def get(self, request):
        status_filtro = request.query_params.get('status')
        qs = AgendamentoConsumidor.objects.filter(consumidor=request.user).order_by('-data_hora')
        if status_filtro:
            qs = qs.filter(status=status_filtro)
        paginator = Paginacao()
        page = paginator.paginate_queryset(qs, request, view=self)

        from apps_serv.vitrine.services import StatusKanbanAgendamentosService
        status_kanban = StatusKanbanAgendamentosService().por_agendamento(page)

        # Uma consulta para a pagina inteira, em vez de uma por agendamento.
        from apps_serv.vitrine.models import NegocioPublico
        logos = dict(
            NegocioPublico.objects
            .filter(schema_name__in={a.schema_name for a in page})
            .values_list('schema_name', 'logo_url')
        )

        serializer = AgendamentoConsumidorSerializer(
            page, many=True, context={'status_kanban': status_kanban, 'logos': logos},
        )
        return paginator.get_paginated_response(serializer.data)


class MeusVinculosView(APIView):
    authentication_classes = [ConsumidorJWTAuthentication]
    permission_classes = [IsAuthenticated]
    pagination_class = Paginacao

    @extend_schema(responses=VinculoNegocioSerializer(many=True), summary='Negócios a que estou vinculado')
    def get(self, request):
        """Devolve os negocios vinculados ja resolvidos.

        Antes saia so o schema_name, e o app baixava a vitrine inteira para
        descobrir de que negocio cada vinculo era. Um vinculo cujo negocio saiu
        da vitrine fica de fora: nao ha o que exibir, e o app ja o descartava
        do lado dele.
        """
        from apps_serv.vitrine.models import NegocioPublico
        from apps_serv.vitrine.serializers import NegocioPublicoSerializer

        vinculos = VinculoConsumidor.objects.filter(consumidor=request.user, ativo=True)
        negocios = {
            n.schema_name: n
            for n in NegocioPublico.objects.filter(
                schema_name__in=[v.schema_name for v in vinculos], ativo=True,
            )
        }

        resultado = []
        for vinculo in vinculos:
            negocio = negocios.get(vinculo.schema_name)
            if negocio is None:
                continue
            dados = NegocioPublicoSerializer(negocio).data
            dados['vinculado_em'] = vinculo.criado_em
            resultado.append(dados)

        return resposta_paginada(request, resultado, self)


_PLACA_ANTIGO   = re.compile(r'^[A-Z]{3}\d{4}$')
_PLACA_MERCOSUL = re.compile(r'^[A-Z]{3}\d[A-Z]\d{2}$')


def _normalizar_placa(valor: str) -> str:
    return re.sub(r'[-\s]', '', valor.strip().upper())


def _placa_valida(valor: str) -> bool:
    norm = _normalizar_placa(valor)
    return bool(_PLACA_ANTIGO.match(norm) or _PLACA_MERCOSUL.match(norm))


_CAMPOS_OBRIGATORIOS = {
    TipoObjeto.VEICULO: ['placa', 'marca', 'modelo'],
    TipoObjeto.PET: ['nome', 'especie', 'porte'],
}

_NOME_EXIBICAO = {
    TipoObjeto.VEICULO: lambda d: f"{d['marca']} {d['modelo']} · {_normalizar_placa(d['placa'])}",
    TipoObjeto.PET: lambda d: f"{d['nome']} ({d['especie']})",
}


class ObjetosConsumidorView(APIView):
    authentication_classes = [ConsumidorJWTAuthentication]
    permission_classes = [IsAuthenticated]
    pagination_class = Paginacao

    @extend_schema(
        responses=ObjetoConsumidorSerializer(many=True),
        parameters=[OpenApiParameter('tipo', str, enum=TipoObjeto.values)],
        summary='Meus pets e veículos',
    )
    def get(self, request):
        tipo = request.query_params.get('tipo')
        qs = ObjetoConsumidor.objects.filter(consumidor=request.user)
        if tipo:
            qs = qs.filter(tipo=tipo)
        return resposta_paginada(
            request, qs, self, lambda pagina: ObjetoConsumidorSerializer(pagina, many=True).data,
        )

    @extend_schema(
        request=ObjetoConsumidorSerializer, responses={201: ObjetoConsumidorSerializer},
        summary='Cadastrar pet ou veículo',
        description=(
            '`dados` é livre, mas exige por tipo: veiculo → placa, marca, modelo; '
            'pet → nome, especie, porte.'
        ),
    )
    def post(self, request):
        tipo = request.data.get('tipo')
        dados = request.data.get('dados', {})

        if tipo not in _CAMPOS_OBRIGATORIOS:
            return erro('Tipo inválido.', status_code=status.HTTP_400_BAD_REQUEST)

        ausentes = [c for c in _CAMPOS_OBRIGATORIOS[tipo] if not dados.get(c)]
        if ausentes:
            return erro(f"Campos obrigatórios: {', '.join(ausentes)}.", status_code=status.HTTP_400_BAD_REQUEST)

        nome_exibicao = _NOME_EXIBICAO[tipo](dados)
        obj = ObjetoConsumidor.objects.create(
            consumidor=request.user,
            tipo=tipo,
            dados=dados,
            nome_exibicao=nome_exibicao,
        )
        return Response(ObjetoConsumidorSerializer(obj).data, status=status.HTTP_201_CREATED)


class ObjetoConsumidorDetailView(APIView):
    authentication_classes = [ConsumidorJWTAuthentication]
    permission_classes = [IsAuthenticated]

    @extend_schema(request=None, responses={204: None}, summary='Remover pet ou veículo')
    def delete(self, request, objeto_id):
        try:
            obj = ObjetoConsumidor.objects.get(id=objeto_id, consumidor=request.user)
        except ObjetoConsumidor.DoesNotExist:
            return erro('Não encontrado.', status_code=status.HTTP_404_NOT_FOUND)
        obj.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class CancelarAgendamentoView(APIView):
    authentication_classes = [ConsumidorJWTAuthentication]
    permission_classes = [IsAuthenticated]

    @extend_schema(
        request=None, responses=CancelamentoAgendamentoSerializer,
        summary='Cancelar agendamento (fora do prazo gera taxa)',
    )
    def post(self, request, agendamento_id):
        try:
            agendamento = AgendamentoConsumidor.objects.get(id=agendamento_id, consumidor=request.user)
        except AgendamentoConsumidor.DoesNotExist:
            return erro('Agendamento não encontrado.', status_code=status.HTTP_404_NOT_FOUND)

        from apps_serv.vitrine.services import CancelarAgendamentoService
        try:
            resultado = CancelarAgendamentoService().cancelar(agendamento, request.user)
        except (ValueError, PermissionError) as e:
            return erro(str(e), getattr(e, 'code', None), status.HTTP_400_BAD_REQUEST)

        return Response({
            'detail': 'Agendamento cancelado.',
            'taxa': resultado['taxa'],
        })
