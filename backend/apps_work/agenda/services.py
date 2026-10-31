from datetime import date, datetime, time, timedelta
from decimal import Decimal
from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework.exceptions import ValidationError
from core.excecoes import ErroDeNegocio
from core.grade import inicios_livres
from .models import (
    Agendamento, AgendamentoServico, Bloqueio, OrigemAtendimento, PagamentoAgendamento, StatusAgendamento,
)

DURACAO_PADRAO_MINUTOS = 30

# O que segura o horário do profissional. Concluído e faltou já tiveram
# desfecho: o horário volta a ficar livre para quem chegar.
STATUS_QUE_OCUPAM = (StatusAgendamento.AGENDADO, StatusAgendamento.CONFIRMADO)

ERRO_HORARIO_CONFLITO = {
    'detail': 'Esse colaborador já tem um agendamento nesse horário.',
    'code': 'horario_conflito',
}

ERRO_HORARIO_BLOQUEADO = {
    'detail': 'Esse horário está bloqueado na agenda do profissional.',
    'code': 'horario_bloqueado',
}


class DiasComRegistroService:
    """Datas de um mês que já têm atendimento marcado, somando os dois modos de
    agenda. A interface usa isso para não esconder um dia fechado que tenha
    registro — sem essa checagem, mudar o horário de funcionamento tornaria
    invisível o que já estava agendado naquele dia da semana."""

    def listar(self, ano: int, mes: int) -> list[str]:
        from apps_work.kanban.models import AtendimentoKanban

        datas = set(
            Agendamento.objects
            .filter(data_hora__year=ano, data_hora__month=mes)
            .exclude(status=StatusAgendamento.CANCELADO)
            .values_list('data_hora__date', flat=True)
        )
        datas.update(
            AtendimentoKanban.objects
            .filter(data__year=ano, data__month=mes, data__isnull=False)
            .values_list('data', flat=True)
        )
        return sorted(d.isoformat() for d in datas)


class PendenciasCobrancaService:
    """Atendimentos que já passaram da data e nunca foram cobrados.

    A agenda mostra um dia por vez e o caixa é montado a partir das linhas de
    PagamentoAgendamento: sem essa lista, o que ficou para trás não aparece em lugar
    nenhum, e o faturamento fica menor do que o que de fato entrou.

    Junta as duas origens como o CaixaService faz — quem consome não precisa
    saber se o negócio usa agenda por horário ou esteira.
    """

    def listar(self, hoje: date | None = None) -> list[dict]:
        from apps_work.kanban.models import AtendimentoKanban

        hoje = hoje or timezone.localdate()
        pendencias = []

        agendamentos = (
            Agendamento.objects
            .filter(data_hora__date__lt=hoje, status__in=[StatusAgendamento.AGENDADO, StatusAgendamento.CONFIRMADO])
            .select_related('cliente')
            .prefetch_related('servicos__servico')
        )
        for ag in agendamentos:
            servicos = list(ag.servicos.all())
            pendencias.append({
                'origem': OrigemAtendimento.AGENDA,
                'id': ag.pk,
                'data': ag.data_hora.astimezone().date().isoformat(),
                'cliente_id': ag.cliente_id,
                'cliente_nome': ag.cliente.nome,
                'servico_nome': ' + '.join(s.servico.nome for s in servicos) or '—',
                # a mesma conta da cobrança: serviços + acréscimo - desconto
                'valor': str(sum((s.preco_cobrado for s in servicos), Decimal('0')) + ag.acrescimo - ag.desconto),
                # No formato que o CobrancaModal consome, pra cobrar direto da
                # lista sem precisar abrir a agenda naquele dia.
                'servicos': [
                    {'servico_id': s.servico_id, 'nome': s.servico.nome, 'preco': str(s.preco_cobrado)}
                    for s in servicos
                ],
            })

        atendimentos = (
            AtendimentoKanban.objects
            .filter(data__lt=hoje, pago=False, faltou=False, data__isnull=False)
            .select_related('objeto__cliente', 'servico')
        )
        for at in atendimentos:
            pendencias.append({
                'origem': OrigemAtendimento.KANBAN,
                'id': at.pk,
                'data': at.data.isoformat(),
                # o avulso da esteira não tem cliente: id nulo, e o nome é a identificação
                'cliente_id': at.objeto.cliente_id if not at.avulso else None,
                'cliente_nome': at.rotulo,
                'servico_nome': at.servico.nome,
                'valor': str(at.servico.preco + at.acrescimo - at.desconto),
                'servicos': [
                    {'servico_id': at.servico_id, 'nome': at.servico.nome, 'preco': str(at.servico.preco)}
                ],
            })

        # Mais antigo primeiro: é o que está há mais tempo fora do caixa.
        pendencias.sort(key=lambda p: p['data'])
        return pendencias


class SlotsAgendaService:
    """Grade de horários de um colaborador num dia, como o quadro da esteira.

    A agenda por horário sempre foi escolha às cegas: o usuário digitava a hora
    e só descobria o choque ao salvar. Aqui a ocupação vira grade, no mesmo
    formato do SlotService do kanban, para o app poder reaproveitar a tela.

    A agenda é individual — a grade olha só os agendamentos daquele colaborador,
    e a ocupação de um não interfere na do outro.
    """

    def listar(self, data: date, servico_id: int, colaborador_id: int) -> list[dict]:
        """Os horários livres do dia para este serviço com este profissional."""
        from apps_work.servicos.models import Servico

        servico = Servico.objects.filter(pk=servico_id, ativo=True).first()
        if not servico:
            return []

        return [
            {'horario': inicio.strftime('%H:%M'), 'disponivel': True}
            for inicio in self.livres(data, colaborador_id, servico.duracao)
        ]

    def livres(
        self, data: date, colaborador_id: int, duracao_minutos: int | None, nao_antes_de: datetime | None = None,
    ) -> list[datetime]:
        """Os inícios livres do dia, no horário local e sem fuso.

        Candidatos: a grade de 15 em 15 minutos a partir da abertura e, além
        dela, o fim de cada agendamento já marcado — acabou um às 9:20, o 9:20
        é oferecido, sem esperar o 9:30. Só os que cabem inteiros (o serviço
        todo antes do fechamento, sem bater em ninguém) entram; a grade da
        agenda já mostra o que está ocupado, então os ocupados não vêm.

        Recebe a duração, e não o serviço, porque o app do cliente marca vários
        serviços de uma vez. `nao_antes_de` (local, sem fuso) é a antecedência
        de quem pede: o app do cliente passa agora + 30 min; a empresa não passa.
        """
        from apps_work.empresa.models import HorarioFuncionamento

        horario = HorarioFuncionamento.objects.filter(dia=data.weekday(), ativo=True).first()
        if not horario or not horario.abertura or not horario.fechamento:
            return []

        # A grade é a mesma da esteira (core/grade.py); a agenda é individual,
        # então cabe um atendimento por vez no profissional.
        return inicios_livres(
            datetime.combine(data, horario.abertura),
            datetime.combine(data, horario.fechamento),
            timedelta(minutes=duracao_minutos or DURACAO_PADRAO_MINUTOS),
            self._intervalos_ocupados(data, colaborador_id),
            nao_antes_de=nao_antes_de,
        )

    def _intervalos_ocupados(self, data: date, colaborador_id: int) -> list[tuple]:
        agendamentos = (
            Agendamento.objects
            .filter(data_hora__date=data, colaborador_id=colaborador_id, status__in=STATUS_QUE_OCUPAM)
            .prefetch_related('servicos__servico')
        )
        intervalos = []
        for ag in agendamentos:
            duracao = sum(s.servico.duracao for s in ag.servicos.all()) or DURACAO_PADRAO_MINUTOS
            # localtime, e não astimezone(): este usa o fuso do sistema
            # operacional, que pode não ser o do Django.
            inicio = timezone.localtime(ag.data_hora).replace(tzinfo=None)
            intervalos.append((inicio, inicio + timedelta(minutes=duracao)))
        return intervalos + BloqueioService().intervalos_do_dia(data, colaborador_id)


class BloqueioService:
    """Os bloqueios da agenda: o que eles tiram da grade e a regra para criar.

    Dois tipos: o de um profissional (com colaborador), que tira o trecho da
    agenda dele; e o do negócio (sem colaborador), que fecha o negócio inteiro
    no período — vale na agenda de todos e na esteira, que não tem agenda
    individual.

    Não existe editar: para mudar, a pessoa exclui e cria de novo, e a regra
    de não bloquear em cima de cliente só precisa valer na criação.
    """

    def do_dia(self, data: date):
        """Os bloqueios que valem num dia (o fixo vale de `data_inicio` em diante)."""
        return (
            Bloqueio.objects
            .filter(data_inicio__lte=data)
            .filter(Q(data_fim__isnull=True) | Q(data_fim__gte=data))
        )

    def intervalos_do_dia(self, data: date, colaborador_id: int) -> list[tuple]:
        """Os trechos bloqueados do dia na agenda de um profissional, no
        horário local e sem fuso, no mesmo formato dos agendamentos da grade:
        os dele e os do negócio inteiro, que fecham a agenda de todos. O dia
        inteiro vai da meia-noite à meia-noite seguinte."""
        return [
            self._intervalo(b, data)
            for b in self.do_dia(data).filter(Q(colaborador_id=colaborador_id) | Q(colaborador__isnull=True))
        ]

    def intervalos_do_negocio(self, data: date) -> list[tuple]:
        """Só os trechos em que o negócio inteiro está fechado no dia. É o que
        a esteira usa: lá não há agenda individual."""
        return [self._intervalo(b, data) for b in self.do_dia(data).filter(colaborador__isnull=True)]

    @transaction.atomic
    def criar(
        self, data_inicio: date, colaborador=None, data_fim: date | None = None,
        hora_inicio: time | None = None, hora_fim: time | None = None, motivo: str = '',
    ) -> Bloqueio:
        # os opcionais podem nem vir no pedido: o fixo não manda data_fim, o
        # dia inteiro não manda as horas, o do negócio não manda colaborador
        bloqueio = Bloqueio(
            colaborador=colaborador, data_inicio=data_inicio, data_fim=data_fim,
            hora_inicio=hora_inicio, hora_fim=hora_fim, motivo=motivo,
        )
        if self._tem_cliente(bloqueio):
            raise ErroDeNegocio(
                'Você tem cliente agendado nesse horário. Para bloquear, reagende ou cancele o atendimento primeiro.',
                'bloqueio_com_cliente',
            )
        bloqueio.save()
        return bloqueio

    def _tem_cliente(self, bloqueio: Bloqueio) -> bool:
        """Algum atendimento ainda por acontecer cai dentro do bloqueio. No
        fixo, olha todas as datas a partir do início, não só a primeira. O do
        negócio olha a agenda de todos os profissionais e também a esteira."""
        agora = timezone.localtime().replace(tzinfo=None)
        agendamentos = (
            Agendamento.objects
            .filter(status__in=STATUS_QUE_OCUPAM, data_hora__date__gte=bloqueio.data_inicio)
            .prefetch_related('servicos__servico')
        )
        # o do negócio fecha a agenda de todos: nenhum profissional fica de fora
        if bloqueio.colaborador_id is not None:
            agendamentos = agendamentos.filter(colaborador=bloqueio.colaborador)
        if bloqueio.data_fim:
            agendamentos = agendamentos.filter(data_hora__date__lte=bloqueio.data_fim)

        for ag in agendamentos:
            duracao = sum(s.servico.duracao for s in ag.servicos.all()) or DURACAO_PADRAO_MINUTOS
            inicio = timezone.localtime(ag.data_hora).replace(tzinfo=None)
            if self._cai_no_bloqueio(bloqueio, inicio, inicio + timedelta(minutes=duracao), agora):
                return True

        return bloqueio.colaborador_id is None and self._tem_atendimento_na_esteira(bloqueio, agora)

    def _tem_atendimento_na_esteira(self, bloqueio: Bloqueio, agora: datetime) -> bool:
        """Os cards da esteira com hora marcada dentro do período (quem faltou
        não conta), ocupando a duração prevista. O card sem hora não cai em
        faixa nenhuma e não impede: ele continua marcado, só não entra mais
        ninguém."""
        from apps_work.kanban.models import AtendimentoKanban

        atendimentos = (
            AtendimentoKanban.objects
            .filter(faltou=False, data__gte=bloqueio.data_inicio, horario_entrada__isnull=False)
            .select_related('servico')
        )
        if bloqueio.data_fim:
            atendimentos = atendimentos.filter(data__lte=bloqueio.data_fim)

        for at in atendimentos:
            inicio = datetime.combine(at.data, at.horario_entrada).replace(second=0, microsecond=0)
            if self._cai_no_bloqueio(bloqueio, inicio, inicio + timedelta(minutes=at.duracao_prevista), agora):
                return True
        return False

    def _cai_no_bloqueio(self, bloqueio: Bloqueio, inicio: datetime, fim: datetime, agora: datetime) -> bool:
        """Se o atendimento [inicio, fim), ainda por acontecer, sobrepõe o
        bloqueio no dia dele."""
        if fim <= agora:
            return False
        inicio_bl, fim_bl = self._intervalo(bloqueio, inicio.date())
        return inicio < fim_bl and inicio_bl < fim

    def _intervalo(self, bloqueio: Bloqueio, data: date) -> tuple[datetime, datetime]:
        if bloqueio.hora_inicio is None:
            return datetime.combine(data, time.min), datetime.combine(data + timedelta(days=1), time.min)
        return datetime.combine(data, bloqueio.hora_inicio), datetime.combine(data, bloqueio.hora_fim)


class AgendamentoService:
    def notificar_mudanca_de_status(self, agendamento: Agendamento, status_anterior: str) -> None:
        """Avisa quem acompanha o agendamento de fora do tenant. Só dispara na
        mudança real — salvar o agendamento sem mexer no status não é evento."""
        if agendamento.status == status_anterior:
            return

        from django.db import connection
        from .signals import agendamento_status_alterado

        agendamento_status_alterado.send(
            sender=Agendamento,
            schema_name=connection.schema_name,
            agendamento_id=agendamento.pk,
            status=agendamento.status,
        )

    def verificar_conflito_para_criacao(self, colaborador, data_hora: datetime, servico_id: int | None) -> None:
        duracao = None
        if servico_id:
            from apps_work.servicos.models import Servico
            servico = Servico.objects.filter(pk=servico_id).first()
            duracao = servico.duracao if servico else None
        self._verificar_conflito(colaborador, data_hora, duracao)

    def verificar_conflito_para_atualizacao(self, agendamento: Agendamento, colaborador, data_hora: datetime) -> None:
        duracao = sum(s.servico.duracao for s in agendamento.servicos.all()) or None
        self._verificar_conflito(colaborador, data_hora, duracao, excluir_id=agendamento.pk)

    def _verificar_conflito(self, colaborador, data_hora: datetime, duracao_minutos: int | None, excluir_id: int | None = None) -> None:
        if colaborador is None:
            return

        duracao = duracao_minutos or DURACAO_PADRAO_MINUTOS
        inicio = data_hora
        fim = data_hora + timedelta(minutes=duracao)

        # O bloqueio vale também para a empresa: para marcar em cima dele, o
        # bloqueio sai antes. Os do negócio inteiro entram junto com os do
        # profissional (intervalos_do_dia).
        inicio_local = timezone.localtime(inicio).replace(tzinfo=None)
        fim_local = inicio_local + timedelta(minutes=duracao)
        for inicio_bl, fim_bl in BloqueioService().intervalos_do_dia(inicio_local.date(), colaborador.pk):
            if inicio_local < fim_bl and inicio_bl < fim_local:
                raise ValidationError(ERRO_HORARIO_BLOQUEADO)

        candidatos = (
            Agendamento.objects
            .filter(colaborador=colaborador, data_hora__date=data_hora.date(), status__in=STATUS_QUE_OCUPAM)
            .prefetch_related('servicos__servico')
        )
        if excluir_id:
            candidatos = candidatos.exclude(pk=excluir_id)

        for outro in candidatos:
            outro_duracao = sum(s.servico.duracao for s in outro.servicos.all()) or DURACAO_PADRAO_MINUTOS
            outro_inicio = outro.data_hora
            outro_fim = outro_inicio + timedelta(minutes=outro_duracao)
            if inicio < outro_fim and outro_inicio < fim:
                raise ValidationError(ERRO_HORARIO_CONFLITO)

    @transaction.atomic
    def cobrar(
        self,
        agendamento: Agendamento,
        desconto: Decimal,
        pagamentos: list,
        credito_aplicado: Decimal = Decimal('0'),
        troco_credito: Decimal = Decimal('0'),
        acrescimo: Decimal = Decimal('0'),
        acrescimo_motivo: str = '',
        servico_ids: list[int] | None = None,
    ) -> Agendamento:
        """Fecha o atendimento. O total é o dos serviços mais o acréscimo menos
        o desconto, e tem de bater com o que o cliente entregou.

        Dois acertos em comum acordo com o cliente cabem aqui, e só aqui:
        `servico_ids` troca os serviços pelos que foram feitos de verdade (os
        AgendamentoServico são substituídos, com o preço atual de cada um — é
        o que deixa o registro e os relatórios certos), e o acréscimo mantém o
        serviço e cobra o que custou a mais, com o motivo que o cliente vê no
        app. Sem nenhum dos dois, cobra o combinado.
        """
        from apps_work.financeiro.services import (
            SaldoService, conferir_total_da_cobranca, notificar_cobranca, snapshot_do_servico,
        )
        from apps_work.servicos.services import servicos_ativos

        if servico_ids:
            servicos = servicos_ativos(servico_ids)
            # .all().delete() também limpa o prefetch da view: a resposta sai
            # com os serviços novos, não com os que ela tinha carregado.
            agendamento.servicos.all().delete()
            AgendamentoServico.objects.bulk_create([
                AgendamentoServico(agendamento=agendamento, servico=servico, preco_cobrado=servico.preco)
                for servico in servicos
            ])
        itens = list(agendamento.servicos.select_related('servico').order_by('pk'))

        total_esperado = conferir_total_da_cobranca(
            sum((item.preco_cobrado for item in itens), Decimal('0')),
            desconto, acrescimo, pagamentos, credito_aplicado,
        )

        saldo_service = SaldoService()

        if credito_aplicado > Decimal('0'):
            saldo_service.aplicar_credito(agendamento.cliente_id, credito_aplicado, agendamento_id=agendamento.pk)

        status_anterior = agendamento.status
        agendamento.desconto = desconto
        agendamento.acrescimo = acrescimo
        agendamento.acrescimo_motivo = acrescimo_motivo
        agendamento.status = StatusAgendamento.CONCLUIDO
        agendamento.save(update_fields=['desconto', 'acrescimo', 'acrescimo_motivo', 'status'])
        self.notificar_mudanca_de_status(agendamento, status_anterior)

        # a comissão do parceiro congela aqui: mudar o acordo depois não
        # reescreve o que já foi cobrado
        colaborador = agendamento.colaborador
        agendamento.pagamentos.all().delete()
        PagamentoAgendamento.objects.bulk_create([
            PagamentoAgendamento(
                agendamento=agendamento, forma=p['forma'], valor=p['valor'],
                comissao_percentual=colaborador.comissao_percentual if colaborador and colaborador.eh_parceiro else None,
                repasse=colaborador.comissao_para(p['valor']) if colaborador else Decimal('0.00'),
            )
            for p in pagamentos
        ])

        if troco_credito > Decimal('0'):
            saldo_service.adicionar_troco(agendamento.cliente_id, troco_credito, agendamento_id=agendamento.pk)

        # o app do cliente passa a mostrar o que foi cobrado de verdade
        notificar_cobranca(
            Agendamento, OrigemAtendimento.AGENDA, agendamento.pk, total_esperado, acrescimo, acrescimo_motivo,
            [snapshot_do_servico(item.servico, item.preco_cobrado) for item in itens],
        )
        return agendamento
