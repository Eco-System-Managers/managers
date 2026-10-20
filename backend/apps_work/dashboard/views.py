from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema

from .serializers import DashboardResumoSerializer
from .services import DashboardService


class DashboardResumoView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses=DashboardResumoSerializer, summary='Resumo do painel')
    def get(self, request):
        return Response(DashboardService().obter_resumo())
