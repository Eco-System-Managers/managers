from decimal import Decimal
import logging

from rest_framework import generics, viewsets, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, OpenApiResponse, extend_schema
from core.permissions import IsProprietario
from .models import EmpresaConfig, HorarioFuncionamento
from .serializers import (
    CoordenadaSerializer, EmpresaConfigSerializer, HorarioFuncionamentoSerializer, LogoSerializer,
    RuaNoPontoSerializer, UploadLogoSerializer,
)
from core.excecoes import erro

from .services import ConfiguracaoEmpresaService

logger = logging.getLogger(__name__)


class GeocodificarView(APIView):
    """Palpite de coordenada para um endereço ainda não salvo.

    Existe por causa do onboarding: o mapa precisa abrir em algum lugar antes de
    o endereço ir para o banco. Devolver o palpite daqui evita reimplementar o
    Nominatim nos dois painéis, e mantém uma única regra de geocodificação.
    """
    permission_classes = [IsAuthenticated]

    @extend_schema(
        responses=CoordenadaSerializer, summary='Palpite de coordenada para um endereço',
        parameters=[
            OpenApiParameter('endereco', OpenApiTypes.STR),
            OpenApiParameter('cidade', OpenApiTypes.STR),
            OpenApiParameter('uf', OpenApiTypes.STR),
        ],
        description='Informe ao menos endereco ou cidade.',
    )
    def get(self, request):
        endereco = request.query_params.get('endereco', '').strip()
        cidade = request.query_params.get('cidade', '').strip()
        uf = request.query_params.get('uf', '').strip()

        if not endereco and not cidade:
            return erro('Informe ao menos o endereço ou a cidade.', status_code=status.HTTP_400_BAD_REQUEST)

        from .services import GeocodificacaoService
        try:
            coords = GeocodificacaoService().geocodificar(endereco, cidade, uf)
        except Exception:
            coords = None

        if not coords:
            # Não é erro: o mapa cai no próximo palpite da cascata (localização
            # do aparelho, centro da cidade) em vez de travar o cadastro.
            return Response({'latitude': None, 'longitude': None})

        return Response(CoordenadaSerializer({'latitude': Decimal(coords[0]), 'longitude': Decimal(coords[1])}).data)


class RuaNoPontoView(APIView):
    """Nome da via onde o pino está, para o dono conferir que acertou a rua."""
    permission_classes = [IsAuthenticated]

    @extend_schema(
        responses=RuaNoPontoSerializer, summary='Nome da via num ponto do mapa',
        parameters=[
            OpenApiParameter('lat', OpenApiTypes.FLOAT, required=True),
            OpenApiParameter('lng', OpenApiTypes.FLOAT, required=True),
        ],
    )
    def get(self, request):
        try:
            latitude = float(request.query_params.get('lat', ''))
            longitude = float(request.query_params.get('lng', ''))
        except (TypeError, ValueError):
            return erro('Coordenada inválida.', status_code=status.HTTP_400_BAD_REQUEST)

        if not (-90 <= latitude <= 90) or not (-180 <= longitude <= 180):
            return erro('Coordenada fora dos limites.', status_code=status.HTTP_400_BAD_REQUEST)

        from .services import GeocodificacaoService
        try:
            rua = GeocodificacaoService().rua_no_ponto(latitude, longitude)
        except Exception:
            rua = None

        # Não saber a rua não é erro: a tela apenas deixa de exibir o rótulo, e
        # o dono segue confirmando o ponto no olho.
        return Response({'rua': rua})


class EmpresaConfigView(generics.RetrieveUpdateAPIView):
    serializer_class = EmpresaConfigSerializer

    def get_permissions(self):
        if self.request.method in ['PUT', 'PATCH']:
            return [IsAuthenticated(), IsProprietario()]
        return [IsAuthenticated()]

    def get_object(self):
        obj, _ = EmpresaConfig.objects.get_or_create(pk=1)
        return obj

    def perform_update(self, serializer):
        config = serializer.instance
        endereco_anterior = (config.endereco, config.numero, config.cidade, config.uf)
        super().perform_update(serializer)
        ConfiguracaoEmpresaService().apos_salvar(serializer.instance, self.request.user, endereco_anterior)


class UploadLogoView(APIView):
    permission_classes = [IsAuthenticated, IsProprietario]

    @extend_schema(
        request={'multipart/form-data': UploadLogoSerializer},
        responses={200: LogoSerializer, 503: OpenApiResponse(description='Armazenamento de imagens indisponível.')},
        summary='Enviar a logo do negócio',
    )
    def post(self, request):
        from django.db import connection
        from .services import ImagemInvalidaError

        arquivo = request.FILES.get('logo')
        if not arquivo:
            return erro('Nenhum arquivo enviado.', 'arquivo_obrigatorio')

        try:
            url = ConfiguracaoEmpresaService().trocar_logo(arquivo)
        except ImagemInvalidaError as e:
            return erro(str(e), getattr(e, 'code', None) or 'imagem_invalida')
        except Exception:
            # A mensagem do provedor pode carregar detalhe de infraestrutura;
            # ela vai para o log, e o cliente recebe algo genérico.
            logger.exception('Falha ao enviar a logo', extra={'schema_name': connection.schema_name})
            return erro(
                'Não foi possível enviar a imagem. Tente novamente.', 'armazenamento_indisponivel',
                status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        return Response({'logo_url': url})


class HorarioFuncionamentoViewSet(viewsets.ModelViewSet):
    serializer_class = HorarioFuncionamentoSerializer
    # Sempre os 7 dias da semana: lista fixa, sem paginação.
    pagination_class = None

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsAuthenticated(), IsProprietario()]
        return [IsAuthenticated()]

    def get_queryset(self):
        return HorarioFuncionamento.objects.all()

    def create(self, request, *args, **kwargs):
        dia = request.data.get('dia')
        instance, created = HorarioFuncionamento.objects.get_or_create(dia=dia)
        serializer = self.get_serializer(instance, data=request.data, partial=not created)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        code = status.HTTP_201_CREATED if created else status.HTTP_200_OK
        return Response(serializer.data, status=code)
