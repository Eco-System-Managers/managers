import math
from datetime import datetime

from django.db.models import CharField, F, Func, Q, Value
from django.utils import timezone
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps_serv.autenticacao.authentication import ConsumidorJWTAuthentication
from apps_serv.consumidores.serializers import AgendamentoConsumidorSerializer, VinculoNegocioSerializer
from .models import NegocioPublico
from .serializers import (
    CriarAgendamentoSerializer,
    DisponibilidadeSerializer,
    HorarioNegocioSerializer,
    MembroEquipeSerializer,
    NegocioPublicoSerializer,
    ServicoVitrineSerializer,
)
from .services import AgendamentoTenantService, CrossTenantQueryService, VincularNegocioService
from core.excecoes import ErroDeNegocio, erro
from core.paginacao import Paginacao, resposta_paginada
from core.schemas import schema_valido

def _schema_valido(schema_name: str) -> bool:
    return schema_valido(schema_name)


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
        raise ErroDeNegocio('Coordenadas ou raio inválidos.', 'coordenadas_invalidas')

    if not (-90 <= lat <= 90) or not (-180 <= lng <= 180) or raio <= 0:
        raise ErroDeNegocio('Coordenadas ou raio inválidos.', 'coordenadas_invalidas')

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
    pagination_class = Paginacao

    @extend_schema(
        operation_id='negocios_list',
        responses=NegocioPublicoSerializer(many=True),
        parameters=[
            OpenApiParameter('nicho', str, description='Negócios que atendem este nicho (slug).'),
            OpenApiParameter('cidade', str),
            OpenApiParameter('search', str, description='Busca em nome, cidade e nicho.'),
            OpenApiParameter('lat', float),
            OpenApiParameter('lng', float),
            OpenApiParameter('raio_km', float, description='Padrão 50 km; só vale com lat e lng.'),
        ],
        summary='Vitrine de negócios',
    )
    def get(self, request):
        qs = NegocioPublico.objects.filter(ativo=True)
        nicho = request.query_params.get('nicho')
        cidade = request.query_params.get('cidade')
        busca = (request.query_params.get('search') or '').strip()
        if nicho:
            # O negocio aparece no filtro de cada um dos seus nichos.
            qs = qs.filter(nichos__contains=[nicho.lower()])
        if cidade:
            qs = qs.filter(cidade__iexact=cidade)
        if busca:
            # Os nichos casam pelo valor guardado, que e slug (`banho_tosa`),
            # nao pelo rotulo exibido — os rotulos vivem nos apps. Termo de uma
            # palavra encontra; "Banho & Tosa" escrito por extenso, nao.
            qs = qs.annotate(
                nichos_texto=Func(F('nichos'), Value(' '), function='array_to_string', output_field=CharField()),
            ).filter(
                Q(nome__icontains=busca)
                | Q(cidade__icontains=busca)
                | Q(nichos_texto__icontains=busca)
            )

        # Coordenada ou raio inválido levanta ErroDeNegocio → 400 pelo handler.
        qs = _filtrar_por_area(qs, request.query_params)

        return resposta_paginada(
            request, qs, self, lambda pagina: NegocioPublicoSerializer(pagina, many=True).data,
        )


class CidadesView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(responses=list[str], summary='Cidades com negócio na vitrine')
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

    @extend_schema(operation_id='negocios_retrieve', responses=NegocioPublicoSerializer, summary='Um negócio da vitrine')
    def get(self, request, schema_name):
        if not _schema_valido(schema_name):
            return erro('Identificador de negócio inválido.', status_code=status.HTTP_400_BAD_REQUEST)

        negocio = NegocioPublico.objects.filter(schema_name=schema_name, ativo=True).first()
        if negocio is None:
            return erro('Negócio não encontrado.', status_code=status.HTTP_404_NOT_FOUND)

        return Response(NegocioPublicoSerializer(negocio).data)


class NichosView(APIView):
    """Nichos presentes na vitrine. Espelha CidadesView: serve para montar os
    filtros sem o app precisar baixar todos os negocios para deduzir a lista."""
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(
        responses=list[str],
        parameters=[OpenApiParameter('cidade', str)],
        summary='Nichos presentes na vitrine',
    )
    def get(self, request):
        qs = NegocioPublico.objects.filter(ativo=True)
        cidade = request.query_params.get('cidade')
        if cidade:
            qs = qs.filter(cidade__iexact=cidade)
        # Cada negocio tem de 1 a 4 nichos; a lista junta todos, sem repetir.
        nichos = {nicho for lista in qs.values_list('nichos', flat=True) for nicho in lista}
        return Response(sorted(nichos))


class ServicosNegocioView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    pagination_class = Paginacao

    @extend_schema(responses=ServicoVitrineSerializer(many=True), summary='Serviços ativos do negócio')
    def get(self, request, schema_name):
        if not _schema_valido(schema_name):
            return erro('Identificador de negócio inválido.', status_code=status.HTTP_400_BAD_REQUEST)

        if not NegocioPublico.objects.filter(schema_name=schema_name, ativo=True).exists():
            return erro('Negócio não encontrado.', status_code=status.HTTP_404_NOT_FOUND)

        servicos = CrossTenantQueryService().listar_servicos(schema_name)
        return resposta_paginada(request, servicos, self)


class EquipeNegocioView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    pagination_class = Paginacao

    @extend_schema(responses=MembroEquipeSerializer(many=True), summary='Equipe ativa do negócio')
    def get(self, request, schema_name):
        if not _schema_valido(schema_name):
            return erro('Identificador de negócio inválido.', status_code=status.HTTP_400_BAD_REQUEST)
        if not NegocioPublico.objects.filter(schema_name=schema_name, ativo=True).exists():
            return erro('Negócio não encontrado.', status_code=status.HTTP_404_NOT_FOUND)
        equipe = CrossTenantQueryService().listar_colaboradores(schema_name)
        return resposta_paginada(request, equipe, self)


class HorariosNegocioView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(responses=HorarioNegocioSerializer(many=True), summary='Horários da semana (sempre 7 dias)')
    def get(self, request, schema_name):
        if not _schema_valido(schema_name):
            return erro('Identificador de negócio inválido.', status_code=status.HTTP_400_BAD_REQUEST)
        if not NegocioPublico.objects.filter(schema_name=schema_name, ativo=True).exists():
            return erro('Negócio não encontrado.', status_code=status.HTTP_404_NOT_FOUND)
        horarios = CrossTenantQueryService().listar_horarios(schema_name)
        return Response(horarios)


class DisponibilidadeView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(
        responses=DisponibilidadeSerializer,
        parameters=[
            OpenApiParameter(
                'data', OpenApiTypes.DATE, required=True,
                description='YYYY-MM-DD, de hoje a 30 dias à frente; depois disso a lista vem vazia.',
            ),
            OpenApiParameter('servico_id', int, required=True, many=True, explode=True),
            OpenApiParameter(
                'colaborador_id', int,
                description='Obrigatório no modo horário (400 colaborador_obrigatorio); ignorado na esteira.',
            ),
        ],
        summary='Horários livres num dia',
    )
    def get(self, request, schema_name):
        if not _schema_valido(schema_name):
            return erro('Identificador de negócio inválido.', status_code=status.HTTP_400_BAD_REQUEST)

        data_str = request.query_params.get('data')
        servico_ids = request.query_params.getlist('servico_id')
        colaborador_id = request.query_params.get('colaborador_id')

        if not data_str or not servico_ids:
            return erro('Parâmetros obrigatórios: data (YYYY-MM-DD) e servico_id.', status_code=status.HTTP_400_BAD_REQUEST)

        try:
            data = datetime.strptime(data_str, '%Y-%m-%d').date()
        except ValueError:
            return erro('Formato de data inválido. Use YYYY-MM-DD.', status_code=status.HTTP_400_BAD_REQUEST)

        # localdate, e não now().date(): esse é o dia em UTC, que depois das 21h
        # já é amanhã e fazia o próprio dia contar como passado.
        if data < timezone.localdate():
            return erro('Data não pode ser no passado.', status_code=status.HTTP_400_BAD_REQUEST)

        if not NegocioPublico.objects.filter(schema_name=schema_name, ativo=True).exists():
            return erro('Negócio não encontrado.', status_code=status.HTTP_404_NOT_FOUND)

        try:
            servico_ids = [int(i) for i in servico_ids]
            colaborador_id = int(colaborador_id) if colaborador_id else None
        except ValueError:
            # Rota pública: valor não numérico dava 500.
            return erro('servico_id e colaborador_id devem ser números.', 'parametros_invalidos')

        slots = CrossTenantQueryService().listar_disponibilidade(
            schema_name=schema_name,
            data=data,
            servico_ids=servico_ids,
            colaborador_id=colaborador_id,
        )
        return Response({'data': data_str, 'slots': slots})


class VincularNegocioView(APIView):
    authentication_classes = [ConsumidorJWTAuthentication]
    permission_classes = [IsAuthenticated]

    @extend_schema(request=None, responses={201: VinculoNegocioSerializer}, summary='Vincular-me ao negócio')
    def post(self, request, schema_name):
        if not _schema_valido(schema_name):
            return erro('Identificador de negócio inválido.', status_code=status.HTTP_400_BAD_REQUEST)
        negocio = NegocioPublico.objects.filter(schema_name=schema_name, ativo=True).first()
        if negocio is None:
            return erro('Negócio não encontrado.', status_code=status.HTTP_404_NOT_FOUND)
        try:
            vinculo = VincularNegocioService().vincular(schema_name, request.user)
        except ValueError as e:
            return erro(str(e), getattr(e, 'code', None), status.HTTP_400_BAD_REQUEST)
        # Mesmo formato de um item de /vinculos/: o app já insere na lista.
        dados = NegocioPublicoSerializer(negocio).data
        dados['vinculado_em'] = vinculo.criado_em
        return Response(dados, status=status.HTTP_201_CREATED)

    @extend_schema(request=None, responses={204: None}, summary='Desfazer o vínculo com o negócio')
    def delete(self, request, schema_name):
        if not _schema_valido(schema_name):
            return erro('Identificador de negócio inválido.', status_code=status.HTTP_400_BAD_REQUEST)
        try:
            VincularNegocioService().desvincular(schema_name, request.user)
        except ValueError as e:
            return erro(str(e), getattr(e, 'code', None), status.HTTP_400_BAD_REQUEST)
        return Response(status=status.HTTP_204_NO_CONTENT)


class CriarAgendamentoView(APIView):
    authentication_classes = [ConsumidorJWTAuthentication]
    permission_classes = [IsAuthenticated]

    @extend_schema(
        request=CriarAgendamentoSerializer, responses={201: AgendamentoConsumidorSerializer},
        summary='Agendar no negócio',
    )
    def post(self, request, schema_name):
        if not _schema_valido(schema_name):
            return erro('Identificador de negócio inválido.', status_code=status.HTTP_400_BAD_REQUEST)

        consumidor = request.user

        if not NegocioPublico.objects.filter(schema_name=schema_name, ativo=True).exists():
            return erro('Negócio não encontrado.', status_code=status.HTTP_404_NOT_FOUND)

        servico_ids = request.data.get('servico_ids', [])
        data_hora_str = request.data.get('data_hora')
        colaborador_id = request.data.get('colaborador_id')
        objeto_id = request.data.get('objeto_id')

        if not servico_ids or not data_hora_str:
            return erro('Campos obrigatórios: servico_ids e data_hora.', status_code=status.HTTP_400_BAD_REQUEST)

        try:
            data_hora = datetime.fromisoformat(data_hora_str)
            if timezone.is_naive(data_hora):
                data_hora = timezone.make_aware(data_hora)
        except ValueError:
            return erro('Formato de data_hora inválido. Use ISO 8601.', status_code=status.HTTP_400_BAD_REQUEST)

        if data_hora <= timezone.now():
            return erro('O agendamento deve ser para uma data futura.', status_code=status.HTTP_400_BAD_REQUEST)

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
            return erro(str(e), getattr(e, 'code', None), status.HTTP_400_BAD_REQUEST)

        return Response(AgendamentoConsumidorSerializer(agendamento).data, status=status.HTTP_201_CREATED)
