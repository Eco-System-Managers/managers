import math
import re
from datetime import datetime

from django.db.models import Q
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps_serv.autenticacao.authentication import ConsumidorJWTAuthentication
from apps_serv.consumidores.serializers import AgendamentoConsumidorSerializer
from .models import NegocioPublico
from .serializers import NegocioPublicoSerializer
from .services import AgendamentoTenantService, CrossTenantQueryService, VincularNegocioService

_SCHEMA_NAME_RE = re.compile(r'^[a-z0-9_]+$')


def _schema_valido(schema_name: str) -> bool:
    return bool(_SCHEMA_NAME_RE.match(schema_name))


_RAIO_PADRAO_KM = 50.0
_KM_POR_GRAU_LAT = 111.32


def _filtrar_por_area(qs, params):
    """Recorta a vitrine numa caixa ao redor de um ponto.

    Existe para o mapa nao pedir a plataforma inteira quando ainda nao ha cidade
    definida — o que acontece enquanto o GPS resolve, e tambem quando o usuario
    esta num municipio sem nenhum negocio cadastrado.

    E uma caixa, nao um circulo: o exagero nos cantos e irrelevante para
    recortar pins de mapa e evita trazer PostGIS so por isso.
    """
    lat = params.get('lat')
    lng = params.get('lng')
    if not lat or not lng:
        return qs

    try:
        lat = float(lat)
        lng = float(lng)
        raio = float(params.get('raio_km') or _RAIO_PADRAO_KM)
    except (TypeError, ValueError):
        raise ValueError('Coordenadas ou raio inválidos.')

    if not (-90 <= lat <= 90) or not (-180 <= lng <= 180) or raio <= 0:
        raise ValueError('Coordenadas ou raio inválidos.')

    delta_lat = raio / _KM_POR_GRAU_LAT
    # Um grau de longitude encurta conforme se afasta do equador. Perto dos
    # polos o cosseno tende a zero, entao o piso evita divisao por ~0 gerando
    # uma caixa de largura infinita.
    km_por_grau_lng = max(_KM_POR_GRAU_LAT * math.cos(math.radians(lat)), 0.1)
    delta_lng = raio / km_por_grau_lng

    return qs.filter(
        latitude__gte=lat - delta_lat, latitude__lte=lat + delta_lat,
        longitude__gte=lng - delta_lng, longitude__lte=lng + delta_lng,
    )


class NegociosPublicosView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request):
        qs = NegocioPublico.objects.filter(ativo=True)
        nicho = request.query_params.get('nicho')
        cidade = request.query_params.get('cidade')
        busca = (request.query_params.get('search') or '').strip()
        if nicho:
            qs = qs.filter(nicho__iexact=nicho)
        if cidade:
            qs = qs.filter(cidade__iexact=cidade)
        if busca:
            # `nicho` casa pelo valor guardado, que e slug (`banho_tosa`), nao
            # pelo rotulo exibido — os rotulos vivem nos apps. Termo de uma
            # palavra encontra; "Banho & Tosa" escrito por extenso, nao.
            qs = qs.filter(
                Q(nome__icontains=busca)
                | Q(cidade__icontains=busca)
                | Q(nicho__icontains=busca)
            )

        try:
            qs = _filtrar_por_area(qs, request.query_params)
        except ValueError as erro:
            return Response({'detail': str(erro)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(NegocioPublicoSerializer(qs, many=True).data)


class CidadesView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request):
        cidades = (
            NegocioPublico.objects
            .filter(ativo=True)
            .exclude(cidade='')
            .values_list('cidade', flat=True)
            .distinct()
            .order_by('cidade')
        )
        return Response(list(cidades))


class NegocioPublicoDetailView(APIView):
    """Um negocio pelo schema.

    Existe para a tela de perfil nao precisar baixar a vitrine inteira so para
    achar um registro — era isso que o app fazia, e o custo crescia junto com a
    plataforma.
    """
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request, schema_name):
        if not _schema_valido(schema_name):
            return Response({'detail': 'Identificador de negócio inválido.'}, status=status.HTTP_400_BAD_REQUEST)

        negocio = NegocioPublico.objects.filter(schema_name=schema_name, ativo=True).first()
        if negocio is None:
            return Response({'detail': 'Negócio não encontrado.'}, status=status.HTTP_404_NOT_FOUND)

        return Response(NegocioPublicoSerializer(negocio).data)


class NichosView(APIView):
    """Nichos presentes na vitrine. Espelha CidadesView: serve para montar os
    filtros sem o app precisar baixar todos os negocios para deduzir a lista."""
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request):
        qs = NegocioPublico.objects.filter(ativo=True)
        cidade = request.query_params.get('cidade')
        if cidade:
            qs = qs.filter(cidade__iexact=cidade)
        nichos = (
            qs
            .exclude(nicho='')
            .values_list('nicho', flat=True)
            .distinct()
            .order_by('nicho')
        )
        return Response(list(nichos))


class ServicosNegocioView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request, schema_name):
        if not _schema_valido(schema_name):
            return Response({'detail': 'Identificador de negócio inválido.'}, status=status.HTTP_400_BAD_REQUEST)

        if not NegocioPublico.objects.filter(schema_name=schema_name, ativo=True).exists():
            return Response({'detail': 'Negócio não encontrado.'}, status=status.HTTP_404_NOT_FOUND)

        servicos = CrossTenantQueryService().listar_servicos(schema_name)
        return Response(servicos)


class EquipeNegocioView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request, schema_name):
        if not _schema_valido(schema_name):
            return Response({'detail': 'Identificador de negócio inválido.'}, status=status.HTTP_400_BAD_REQUEST)
        if not NegocioPublico.objects.filter(schema_name=schema_name, ativo=True).exists():
            return Response({'detail': 'Negócio não encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        equipe = CrossTenantQueryService().listar_colaboradores(schema_name)
        return Response(equipe)


class HorariosNegocioView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request, schema_name):
        if not _schema_valido(schema_name):
            return Response({'detail': 'Identificador de negócio inválido.'}, status=status.HTTP_400_BAD_REQUEST)
        if not NegocioPublico.objects.filter(schema_name=schema_name, ativo=True).exists():
            return Response({'detail': 'Negócio não encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        horarios = CrossTenantQueryService().listar_horarios(schema_name)
        return Response(horarios)


class DisponibilidadeView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request, schema_name):
        if not _schema_valido(schema_name):
            return Response({'detail': 'Identificador de negócio inválido.'}, status=status.HTTP_400_BAD_REQUEST)

        data_str = request.query_params.get('data')
        servico_ids = request.query_params.getlist('servico_id') or request.query_params.getlist('servico_id[]')
        colaborador_id = request.query_params.get('colaborador_id')

        if not data_str or not servico_ids:
            return Response(
                {'detail': 'Parâmetros obrigatórios: data (YYYY-MM-DD) e servico_id.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            data = datetime.strptime(data_str, '%Y-%m-%d').date()
        except ValueError:
            return Response({'detail': 'Formato de data inválido. Use YYYY-MM-DD.'}, status=status.HTTP_400_BAD_REQUEST)

        if data < timezone.now().date():
            return Response({'detail': 'Data não pode ser no passado.'}, status=status.HTTP_400_BAD_REQUEST)

        if not NegocioPublico.objects.filter(schema_name=schema_name, ativo=True).exists():
            return Response({'detail': 'Negócio não encontrado.'}, status=status.HTTP_404_NOT_FOUND)

        slots = CrossTenantQueryService().listar_disponibilidade(
            schema_name=schema_name,
            data=data,
            servico_ids=[int(i) for i in servico_ids],
            colaborador_id=int(colaborador_id) if colaborador_id else None,
        )
        return Response({'data': data_str, 'slots': slots})


class VincularNegocioView(APIView):
    authentication_classes = [ConsumidorJWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, schema_name):
        if not _schema_valido(schema_name):
            return Response({'detail': 'Identificador de negócio inválido.'}, status=status.HTTP_400_BAD_REQUEST)
        if not NegocioPublico.objects.filter(schema_name=schema_name, ativo=True).exists():
            return Response({'detail': 'Negócio não encontrado.'}, status=status.HTTP_404_NOT_FOUND)
        try:
            VincularNegocioService().vincular(schema_name, request.user)
        except ValueError as e:
            return Response({'detail': str(e)}, status=status.HTTP_400_BAD_REQUEST)
        return Response({'detail': 'Vinculado com sucesso.'}, status=status.HTTP_201_CREATED)

    def delete(self, request, schema_name):
        if not _schema_valido(schema_name):
            return Response({'detail': 'Identificador de negócio inválido.'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            VincularNegocioService().desvincular(schema_name, request.user)
        except ValueError as e:
            return Response({'detail': str(e)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(status=status.HTTP_204_NO_CONTENT)


class CriarAgendamentoView(APIView):
    authentication_classes = [ConsumidorJWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, schema_name):
        if not _schema_valido(schema_name):
            return Response({'detail': 'Identificador de negócio inválido.'}, status=status.HTTP_400_BAD_REQUEST)

        consumidor = request.user

        if not NegocioPublico.objects.filter(schema_name=schema_name, ativo=True).exists():
            return Response({'detail': 'Negócio não encontrado.'}, status=status.HTTP_404_NOT_FOUND)

        servico_ids = request.data.get('servico_ids', [])
        data_hora_str = request.data.get('data_hora')
        colaborador_id = request.data.get('colaborador_id')
        objeto_id = request.data.get('objeto_id')

        if not servico_ids or not data_hora_str:
            return Response(
                {'detail': 'Campos obrigatórios: servico_ids e data_hora.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            data_hora = datetime.fromisoformat(data_hora_str)
            if timezone.is_naive(data_hora):
                data_hora = timezone.make_aware(data_hora)
        except ValueError:
            return Response({'detail': 'Formato de data_hora inválido. Use ISO 8601.'}, status=status.HTTP_400_BAD_REQUEST)

        if data_hora <= timezone.now():
            return Response({'detail': 'O agendamento deve ser para uma data futura.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            agendamento = AgendamentoTenantService().criar(
                schema_name=schema_name,
                consumidor=consumidor,
                servico_ids=servico_ids,
                data_hora=data_hora,
                colaborador_id=colaborador_id,
                objeto_id=objeto_id,
            )
        except ValueError as e:
            return Response({'detail': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(AgendamentoConsumidorSerializer(agendamento).data, status=status.HTTP_201_CREATED)
