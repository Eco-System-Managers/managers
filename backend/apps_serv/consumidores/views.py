import logging

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.utils import OpenApiParameter, extend_schema

from apps_serv.autenticacao.authentication import ConsumidorJWTAuthentication
from .models import AgendamentoConsumidor, ObjetoConsumidor, VinculoConsumidor
from .services import FotoConsumidorService, ObjetoConsumidorService, SincronizarClienteService
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
        from apps_work.empresa.services import ImagemInvalidaError

        arquivo = request.FILES.get('foto')
        if not arquivo:
            return erro('Nenhum arquivo enviado.', 'arquivo_obrigatorio')

        try:
            FotoConsumidorService().trocar(request.user, arquivo)
        except ImagemInvalidaError as e:
            return erro(str(e), getattr(e, 'code', None) or 'imagem_invalida')
        except Exception:
            # A mensagem do provedor pode carregar detalhe de infraestrutura;
            # ela vai para o log, e o cliente recebe algo genérico.
            logger.exception('Falha ao enviar a foto do consumidor', extra={'consumidor_id': request.user.id})
            return erro('Não foi possível enviar a imagem. Tente novamente.', status_code=status.HTTP_500_INTERNAL_SERVER_ERROR)

        return Response(ConsumidorSerializer(request.user).data)

    @extend_schema(request=None, responses=ConsumidorSerializer, summary='Remover foto de perfil')
    def delete(self, request):
        FotoConsumidorService().remover(request.user)
        return Response(ConsumidorSerializer(request.user).data)


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
        # Tipo, campos obrigatórios e placa inválidos levantam ErroDeNegocio.
        obj = ObjetoConsumidorService().cadastrar(
            request.user, request.data.get('tipo'), request.data.get('dados') or {},
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
