"""Os números do uso para acompanhar os testadores (`manage.py relatorio_uso`).

Duas fontes. Os eventos (`EventoDeUso`) dizem o que cada um fez no período:
quem usou, o quê, onde travou e o que demorou. O funil sai dos dados de cada
negócio, contados no schema dele: até onde ele chegou, inclusive o que
aconteceu antes de os eventos existirem.
"""
from dataclasses import dataclass, field
from datetime import date, datetime, time, timedelta

from django.db.models import Avg, Count, Max, Q
from django.db.models.functions import TruncDate
from django.utils import timezone

from .models import EventoDeUso
from core.tenant import com_tenant
from .registro import APP_ABERTO

LIMITE_DAS_LISTAS = 15


@dataclass
class Funil:
    onboarding: bool = False
    modo: str = ''
    servicos: int = 0
    clientes: int = 0
    atendimentos: int = 0
    cobrados: int = 0
    equipe: int = 0
    com_acesso: int = 0
    contratos: int = 0


@dataclass
class Negocio:
    schema_name: str
    nome: str
    desde: date | None
    funil: Funil | None
    ultimo_uso: datetime | None = None
    pessoas: int = 0
    acoes: int = 0
    erros: int = 0


@dataclass
class Relatorio:
    inicio: date
    fim: date
    por_dia: list = field(default_factory=list)
    negocios: list = field(default_factory=list)
    acoes_mais_usadas: list = field(default_factory=list)
    erros_de_regra: list = field(default_factory=list)
    erros_do_servidor: list = field(default_factory=list)
    mais_lentas: list = field(default_factory=list)


def montar(dias: int = 7, schema_name: str | None = None, hoje: date | None = None) -> Relatorio:
    fim = hoje or timezone.localdate()
    inicio = fim - timedelta(days=dias - 1)
    desde = timezone.make_aware(datetime.combine(inicio, time.min))

    eventos = EventoDeUso.objects.filter(criado_em__gte=desde)
    if schema_name:
        eventos = eventos.filter(schema_name=schema_name)
    sucesso = eventos.filter(status__lt=400)
    acoes = sucesso.exclude(evento=APP_ABERTO)

    relatorio = Relatorio(inicio=inicio, fim=fim)

    relatorio.por_dia = list(
        eventos.annotate(dia=TruncDate('criado_em')).values('dia').annotate(
            pessoas=Count('user_id', distinct=True),
            negocios=Count('schema_name', distinct=True, filter=~Q(schema_name='')),
            acoes=Count('id', filter=Q(status__lt=400) & ~Q(evento=APP_ABERTO)),
            erros=Count('id', filter=Q(status__gte=400)),
        ).order_by('dia')
    )
    relatorio.acoes_mais_usadas = list(
        acoes.values('evento').annotate(total=Count('id'), negocios=Count('schema_name', distinct=True))
        .order_by('-total', 'evento')[:LIMITE_DAS_LISTAS]
    )
    relatorio.erros_de_regra = list(
        eventos.filter(status__gte=400, status__lt=500).values('evento', 'codigo', 'status')
        .annotate(total=Count('id'), negocios=Count('schema_name', distinct=True))
        .order_by('-total', 'evento')[:LIMITE_DAS_LISTAS]
    )
    relatorio.erros_do_servidor = list(eventos.filter(status__gte=500).order_by('-criado_em')[:LIMITE_DAS_LISTAS])
    relatorio.mais_lentas = list(
        eventos.exclude(evento=APP_ABERTO).values('evento')
        .annotate(total=Count('id'), media=Avg('duracao_ms'), maximo=Max('duracao_ms'))
        .order_by('-media')[:10]
    )
    relatorio.negocios = _negocios(eventos, schema_name)
    return relatorio


def _negocios(eventos, schema_name: str | None) -> list[Negocio]:
    from apps_work.billing.models import Assinatura
    from tenants.models import Tenant

    tenants = Tenant.objects.order_by('nome')
    if schema_name:
        tenants = tenants.filter(schema_name=schema_name)
    inicio_por_tenant = dict(Assinatura.objects.values_list('tenant_id', 'inicio'))

    # O último uso é de sempre, não só do período: é o que diz quem largou.
    ultimo_uso = dict(
        EventoDeUso.objects.exclude(schema_name='').values('schema_name')
        .annotate(ultimo=Max('criado_em')).values_list('schema_name', 'ultimo')
    )
    no_periodo = {
        linha['schema_name']: linha
        for linha in eventos.values('schema_name').annotate(
            pessoas=Count('user_id', distinct=True),
            acoes=Count('id', filter=Q(status__lt=400) & ~Q(evento=APP_ABERTO)),
            erros=Count('id', filter=Q(status__gte=400)),
        )
    }

    negocios = []
    for tenant in tenants:
        periodo = no_periodo.get(tenant.schema_name, {})
        negocios.append(Negocio(
            schema_name=tenant.schema_name,
            nome=tenant.nome,
            desde=inicio_por_tenant.get(tenant.pk),
            funil=_funil(tenant.schema_name),
            ultimo_uso=ultimo_uso.get(tenant.schema_name),
            pessoas=periodo.get('pessoas', 0),
            acoes=periodo.get('acoes', 0),
            erros=periodo.get('erros', 0),
        ))
    # Quem usou por último primeiro; quem nunca usou, no fim.
    nunca = datetime.min.replace(tzinfo=timezone.get_current_timezone())
    negocios.sort(key=lambda n: n.ultimo_uso or nunca, reverse=True)
    return negocios


def _funil(schema_name: str) -> Funil | None:
    """Até onde o negócio chegou. None quando o negócio não pôde ser lido:
    o relatório segue com os outros."""
    from apps_work.agenda.models import Agendamento
    from apps_work.contratos.models import Contrato
    from apps_work.empresa.models import EmpresaConfig
    from apps_work.kanban.models import AtendimentoKanban
    from apps_work.clientes.models import Cliente
    from apps_work.servicos.models import Servico
    from apps_work.usuarios.models import Colaborador
    from tenants.models import Membro, Papel

    try:
        with com_tenant(schema_name):
            config = EmpresaConfig.objects.first()
            donos = Membro.objects.filter(
                tenant__schema_name=schema_name, papel=Papel.PROPRIETARIO,
            ).values_list('user_id', flat=True)
            return Funil(
                onboarding=bool(config and config.onboarding_concluido),
                modo=config.tipo_agenda if config else '',
                servicos=Servico.objects.count(),
                clientes=Cliente.objects.count(),
                atendimentos=Agendamento.objects.count() + AtendimentoKanban.objects.count(),
                cobrados=(
                    Agendamento.objects.filter(pagamentos__isnull=False).distinct().count()
                    + AtendimentoKanban.objects.filter(pagamentos__isnull=False).distinct().count()
                ),
                equipe=Colaborador.objects.exclude(user_id__in=list(donos)).count(),
                com_acesso=Membro.objects.filter(tenant__schema_name=schema_name, papel=Papel.COLABORADOR).count(),
                contratos=Contrato.objects.count(),
            )
    except Exception:
        return None
