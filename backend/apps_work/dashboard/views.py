from datetime import date

from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.excecoes import erro
from core.permissions import colaborador_aplicado

from .serializers import DashboardResumoSerializer
from .services import DashboardService


class DashboardResumoView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        parameters=[
            OpenApiParameter('data_inicio', OpenApiTypes.DATE, description='Padrão: hoje.'),
            OpenApiParameter('data_fim', OpenApiTypes.DATE, description='Padrão: hoje.'),
            OpenApiParameter(
                'colaborador', OpenApiTypes.INT,
                description='Só a agenda deste profissional (a esteira fica de fora). '
                            'Quem não é proprietário vê sempre os próprios números, ignorando este parâmetro.',
            ),
        ],
        responses=DashboardResumoSerializer,
        summary='Resumo do painel por período',
    )
    def get(self, request):
        try:
            data_inicio = self._data(request.query_params.get('data_inicio'))
            data_fim = self._data(request.query_params.get('data_fim'))
        except ValueError:
            return erro('Data inválida. Use o formato YYYY-MM-DD.', 'parametros_invalidos')
        if data_inicio and data_fim and data_fim < data_inicio:
            return erro('data_fim não pode ser antes de data_inicio.', 'parametros_invalidos')

        colaborador_str = request.query_params.get('colaborador')
        colaborador_id = None
        if colaborador_str:
            if not colaborador_str.isdigit():
                return erro('colaborador deve ser um id numérico.', 'parametros_invalidos')
            colaborador_id = int(colaborador_str)

        # quem não é proprietário vê só o próprio (ErroDeNegocio 404 sem perfil)
        colaborador_id = colaborador_aplicado(request, colaborador_id)

        return Response(DashboardService().obter_resumo(data_inicio, data_fim, colaborador_id))

    @staticmethod
    def _data(valor: str | None) -> date | None:
        return date.fromisoformat(valor) if valor else None
