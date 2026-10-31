from datetime import datetime, timedelta, date, time
from decimal import Decimal
from django.db import connection, transaction
from django.db.models import ProtectedError
from django.utils import timezone
from rest_framework.exceptions import ValidationError
from apps_work.agenda.models import OrigemAtendimento
from core.excecoes import ErroDeNegocio
from core.grade import Intervalo, cabe, inicios_livres, proxima_marca
from .models import AjusteDoDia, AtendimentoKanban, EtapaKanban, PagamentoAtendimento

ERRO_HORARIO_OCUPADO = {
    'detail': 'Não cabe mais ninguém nesse horário. Escolha outro.',
    'code': 'horario_ocupado',
}

# O negócio está fechado nessa hora (um Bloqueio sem colaborador, da agenda).
# O mesmo code que a agenda usa para o bloqueio do profissional.
ERRO_HORARIO_BLOQUEADO = {
    'detail': 'O negócio está fechado nesse horário. Para receber, exclua o bloqueio antes.',
    'code': 'horario_bloqueado',
}

# Quando o serviço não diz quanto leva (não acontece pelo app; vale para a
# grade pedida sem serviço).
DURACAO_PADRAO_MINUTOS = 30

ERRO_FALTA_EM_PAGO = {
    'detail': 'Esse atendimento já foi cobrado. Desfaça a cobrança antes de marcar falta.',
    'code': 'falta_em_pago',
}

ETAPAS_PADRAO = [
    {'nome': 'Aguardando', 'ordem': 0, 'cor': '#F59E0B'},
    {'nome': 'Em atendimento', 'ordem': 1, 'cor': '#3B82F6'},
    {'nome': 'Concluído', 'ordem': 2, 'cor': '#10B981', 'pronto': True},
]

STATUS_AGUARDANDO = 'aguardando'
STATUS_EM_ATENDIMENTO = 'em_atendimento'
STATUS_CONCLUIDO = 'concluido'


class StatusClienteService:
    """Traduz a coluna do quadro no status que o cliente final enxerga no app.

    As etapas são livres — o proprietário cria, renomeia, reordena e apaga —
    então a tradução não pode olhar o nome da coluna. A primeira é a espera;
    a etapa marcada como pronto (e as depois dela) é o fim; o que fica entre
    as duas é atendimento em andamento. Com uma coluna só não existe para
    onde avançar, então ela conta como espera. O quadro padrão (Aguardando /
    Em atendimento / Concluído) cai exatamente nesse desenho.
    """

    def mapa_por_etapa(self) -> dict[int, str]:
        ids = list(EtapaKanban.objects.order_by('ordem').values_list('id', flat=True))
        prontas = EtapaService().ids_prontos() if len(ids) > 1 else set()
        return {
            etapa_id: self._status(indice, etapa_id in prontas)
            for indice, etapa_id in enumerate(ids)
        }

    def _status(self, indice: int, pronta: bool) -> str:
        if indice == 0:
            return STATUS_AGUARDANDO
        if pronta:
            return STATUS_CONCLUIDO
        return STATUS_EM_ATENDIMENTO


class EtapaService:
    def criar_etapas_padrao(self) -> list[EtapaKanban]:
        if EtapaKanban.objects.exists():
            return list(EtapaKanban.objects.all())
        return [EtapaKanban.objects.create(**etapa) for etapa in ETAPAS_PADRAO]

    def etapa_pronto(self) -> EtapaKanban | None:
        """A etapa em que o atendimento está pronto: a marcada pelo dono ou,
        sem marcação (quadro de antes dela), a última. Etapas criadas sem
        `ordem` empatam em 0: o id desempata, para a resposta não variar."""
        return (
            EtapaKanban.objects.filter(pronto=True).first()
            or EtapaKanban.objects.order_by('-ordem', '-id').first()
        )

    def ids_prontos(self) -> set[int]:
        """A etapa de pronto e as que vêm depois dela no quadro.

        A primeira coluna é a espera (StatusClienteService): com uma coluna
        só não existe fim, e nada conta como pronto (o card segura a vaga
        até sair do quadro); se a de pronto foi parar na primeira posição
        por uma reordenação, vale a última, como sem marcação.
        """
        pronto = self.etapa_pronto()
        ids = list(EtapaKanban.objects.order_by('ordem', 'id').values_list('id', flat=True))
        if pronto is None or len(ids) < 2:
            return set()
        posicao = ids.index(pronto.pk)
        if posicao == 0:
            posicao = len(ids) - 1
        return set(ids[posicao:])

    def marcar_pronto(self, etapa: EtapaKanban) -> EtapaKanban:
        """Uma só por negócio: marcar esta desmarca a anterior. Os cards de
        hoje em diante ganham ou perdem a hora de pronto conforme a coluna em
        que estão, para a ocupação do dia seguir a marcação nova."""
        primeira = EtapaKanban.objects.order_by('ordem', 'id').values_list('id', flat=True).first()
        if etapa.pk == primeira:
            raise ErroDeNegocio(
                'A primeira etapa é a de espera. Marque outra como pronto.', 'etapa_pronto_invalida',
            )
        with transaction.atomic():
            EtapaKanban.objects.filter(pronto=True).exclude(pk=etapa.pk).update(pronto=False)
            etapa.pronto = True
            etapa.save(update_fields=['pronto'])
            self.recalcular_pronto_em()
        return etapa

    def recalcular_pronto_em(self) -> None:
        """Acerta o `pronto_em` dos cards de hoje em diante com as etapas que
        contam como pronto agora (depois de marcar ou reordenar). O passado
        fica como estava: é história."""
        prontas = self.ids_prontos()
        de_hoje = AtendimentoKanban.objects.filter(data__gte=timezone.localdate())
        de_hoje.filter(etapa_id__in=prontas, pronto_em__isnull=True).update(pronto_em=timezone.now())
        de_hoje.exclude(etapa_id__in=prontas).filter(pronto_em__isnull=False).update(pronto_em=None)

    def remover(self, etapa: EtapaKanban) -> None:
        # A etapa de pronto libera a vaga e avisa o cliente: sem ela, o quadro
        # fica sem fim. Quem quer tirá-la marca outra antes.
        if etapa.pronto and EtapaKanban.objects.count() > 1:
            raise ErroDeNegocio('Esta etapa é a de pronto. Marque outra como pronto antes de removê-la.', 'etapa_pronto')
        # O FK do atendimento é PROTECT: apagar a coluna com cards dentro
        # derrubaria a view com 500. A pessoa move os cards antes.
        try:
            with transaction.atomic():
                etapa.delete()
                # sem marcação a de pronto é a última: tirar a última muda qual é
                self.recalcular_pronto_em()
        except ProtectedError:
            raise ErroDeNegocio('Esta etapa tem atendimentos e não pode ser removida.', 'etapa_com_atendimentos')

    def reordenar(self, ordem: list) -> None:
        """Grava a nova ordem das colunas.

        O contrato publicado recebe os ids na ordem final (a posição é a
        ordem). A forma antiga, `[{'id', 'ordem'}]`, continua aceita para o
        painel web que ainda a manda.
        """
        with transaction.atomic():
            for posicao, item in enumerate(ordem):
                if isinstance(item, dict):
                    EtapaKanban.objects.filter(pk=item['id']).update(ordem=item['ordem'])
                else:
                    EtapaKanban.objects.filter(pk=item).update(ordem=posicao)
            # A primeira coluna é a espera: a de pronto não pode parar nela
            # (a mesma regra de marcar_pronto). Recusar desfaz a reordenação.
            primeira = EtapaKanban.objects.order_by('ordem', 'id').first()
            if primeira is not None and primeira.pronto and EtapaKanban.objects.count() > 1:
                raise ErroDeNegocio(
                    'A primeira etapa é a de espera: a etapa de pronto não pode ficar nela.', 'etapa_pronto_invalida',
                )
            self.recalcular_pronto_em()


def conferir_identificacao(objeto_id: int | None, identificacao: str) -> None:
    """Ou o veículo/pet ou a identificação. O avulso é o atendimento sem
    objeto, e só o texto diz de quem é o carro no pátio: sem nenhum dos dois o
    card não tem como ser reconhecido (`avulso_sem_identificacao`)."""
    if objeto_id is None and not (identificacao or '').strip():
        raise ErroDeNegocio(
            'Sem veículo ou pet, informe uma identificação para o atendimento ("Hilux branca", "ABC-1234").',
            'avulso_sem_identificacao',
        )


class AtendimentoKanbanService:
    def criar(
        self,
        etapa: EtapaKanban,
        objeto_id: int | None,
        servico_id: int,
        observacao: str = '',
        horario_entrada: time | None = None,
        data: date | None = None,
        colaborador=None,
        conferir_porte: bool = True,
        ignorar_limite: bool = False,
        identificacao: str = '',
        minutos_extras: int = 0,
    ) -> AtendimentoKanban:
        """`objeto_id=None` é o avulso: o cliente que chegou e pediu, sem
        cadastro; aí a `identificacao` é obrigatória.

        `minutos_extras` é o tempo a mais já previsto na chegada ("esse vai
        levar mais 1h"): entra na ocupação desde o começo.

        `conferir_porte=False` é do app do cliente, que já conferiu com o
        porte que o cliente declarou: o cadastro aqui pode ter sido corrigido
        pelo negócio, e o cliente não teria como resolver a diferença.

        `ignorar_limite` é o dono recebendo mesmo com o dia lotado ou a hora
        cheia: para ele o limite é aviso, para o cliente do app é parede. O
        horário em que o negócio está fechado (bloqueio) não tem ignorar: o
        dono que quer receber ali exclui o bloqueio antes.
        """
        from apps_work.clientes.models import ObjetoCliente, porte_do_objeto
        from apps_work.servicos.models import Servico
        from apps_work.servicos.services import conferir_porte as conferir_porte_do_servico
        identificacao = (identificacao or '').strip()
        conferir_identificacao(objeto_id, identificacao)
        objeto = ObjetoCliente.objects.get(pk=objeto_id) if objeto_id is not None else None
        servico = Servico.objects.get(pk=servico_id)
        data = data or timezone.localdate()

        # O porte é do veículo ou do pet: o avulso não tem com o que comparar.
        if conferir_porte and objeto is not None:
            conferir_porte_do_servico(servico, porte_do_objeto(objeto))
        if horario_entrada is not None:
            horario_entrada = horario_entrada.replace(second=0, microsecond=0)
        # A capacidade conta o avulso como qualquer outro: ele ocupa a vaga
        # desde que é lançado, para ninguém marcar em cima dele. Conferir e
        # gravar andam na mesma transação, com o dia travado (ver conferir).
        with transaction.atomic():
            capacidade = CapacidadeService()
            if ignorar_limite:
                capacidade.conferir_bloqueio(data, servico.duracao + minutos_extras, horario_entrada)
            else:
                capacidade.conferir(data, servico.duracao + minutos_extras, horario_entrada)
            # Criado direto numa etapa de pronto (o quadro de uma coluna só, o
            # serviço já feito) nasce com a hora, como se tivesse sido movido.
            pronto_em = self._pronto_em_ao_entrar(None, etapa)
            return AtendimentoKanban.objects.create(
                etapa=etapa,
                objeto=objeto,
                identificacao=identificacao,
                servico=servico,
                observacao=observacao,
                horario_entrada=horario_entrada,
                data=data,
                colaborador=colaborador,
                minutos_extras=minutos_extras,
                pronto_em=pronto_em,
            )

    def mover(self, atendimento: AtendimentoKanban, etapa: EtapaKanban) -> AtendimentoKanban:
        """Chegar na etapa de pronto (ou numa depois dela) libera a vaga e
        guarda a hora; voltar para antes dela desfaz."""
        atendimento.etapa = etapa
        atendimento.pronto_em = self._pronto_em_ao_entrar(atendimento.pronto_em, etapa)
        atendimento.save(update_fields=['etapa', 'pronto_em'])
        return atendimento

    def _pronto_em_ao_entrar(self, pronto_em_atual, etapa: EtapaKanban):
        """O `pronto_em` de um card que entra na `etapa`: a hora que já tinha
        (ou agora) numa etapa de pronto, nulo fora delas."""
        if etapa.pk in EtapaService().ids_prontos():
            return pronto_em_atual or timezone.now()
        return None

    def conferir_alteracao(self, atendimento: AtendimentoKanban, dados: dict, ignorar_limite: bool = False) -> None:
        """As regras do PATCH, antes de gravar (`dados` é o validated_data e
        é alterado no lugar). Tirar o veículo ou pet (virar avulso) ou apagar
        a identificação passa pela regra do avulso; trocar o serviço ou o
        objeto confere o porte; remarcar (dia ou hora) ou trocar o serviço
        confere a capacidade do destino sem contar o próprio card — o máximo
        do dia só quando o dia muda, porque no mesmo dia o card já tem a vaga
        dele —, e `ignorar_limite` passa por cima, como no criar, menos do
        horário em que o negócio está fechado (bloqueio), que não tem ignorar.
        Trocar a etapa segue a regra do mover. Mexer só em pago, observação ou
        tempo a mais não é barrado."""
        from apps_work.clientes.models import porte_do_objeto
        from apps_work.servicos.services import conferir_porte

        objeto = dados.get('objeto', atendimento.objeto)
        if 'objeto' in dados or 'identificacao' in dados:
            conferir_identificacao(
                objeto.pk if objeto is not None else None,
                dados.get('identificacao', atendimento.identificacao),
            )
        if ('servico' in dados or 'objeto' in dados) and objeto is not None:
            conferir_porte(dados.get('servico', atendimento.servico), porte_do_objeto(objeto))
        if any(campo in dados for campo in ('data', 'horario_entrada', 'servico')):
            data = dados.get('data', atendimento.data)
            duracao = (
                dados.get('servico', atendimento.servico).duracao
                + dados.get('minutos_extras', atendimento.minutos_extras)
            )
            horario_entrada = dados.get('horario_entrada', atendimento.horario_entrada)
            if data is not None and ignorar_limite:
                CapacidadeService().conferir_bloqueio(data, duracao, horario_entrada)
            elif data is not None:
                CapacidadeService().conferir(
                    data, duracao, horario_entrada, excluir_id=atendimento.pk, conferir_dia=data != atendimento.data,
                )
        if 'etapa' in dados:
            dados['pronto_em'] = self._pronto_em_ao_entrar(atendimento.pronto_em, dados['etapa'])

    @transaction.atomic
    def cobrar(
        self,
        atendimento: AtendimentoKanban,
        desconto: Decimal,
        pagamentos: list,
        credito_aplicado: Decimal = Decimal('0'),
        troco_credito: Decimal = Decimal('0'),
        acrescimo: Decimal = Decimal('0'),
        acrescimo_motivo: str = '',
        servico_ids: list[int] | None = None,
    ) -> AtendimentoKanban:
        """Fecha o atendimento. O total é o do serviço mais o acréscimo menos
        o desconto, e tem de bater com o que o cliente entregou.

        Dois acertos em comum acordo com o cliente cabem aqui, e só aqui:
        `servico_ids` troca o serviço pelo que foi feito de verdade (um id só,
        porque a esteira tem um serviço por card: `um_servico_so`), e o
        acréscimo mantém o serviço e cobra o que custou a mais, com o motivo
        que o cliente vê no app. Ajustar o tempo previsto (minutos_extras) não
        passa por aqui: tempo é do pátio, preço é acordo.
        """
        from apps_work.clientes.models import porte_do_objeto
        from apps_work.financeiro.services import SaldoService, conferir_total_da_cobranca
        from apps_work.servicos.models import Servico
        from apps_work.servicos.services import conferir_porte, servicos_ativos

        # O avulso não tem cliente, logo não tem comanda: não há de onde tirar
        # crédito nem onde guardar o troco. O dinheiro entra no caixa igual.
        if atendimento.avulso and (credito_aplicado > Decimal('0') or troco_credito > Decimal('0')):
            raise ErroDeNegocio(
                'O atendimento avulso não tem comanda: não dá para aplicar crédito nem guardar troco.',
                'avulso_sem_credito',
            )

        if servico_ids:
            if len(servico_ids) != 1:
                raise ErroDeNegocio(
                    'Na esteira o atendimento tem um serviço só. Escolha um para a troca.', 'um_servico_so',
                )
            servico = servicos_ativos(servico_ids)[0]
            # a mesma trava do receber: o avulso não tem porte com o que comparar
            if atendimento.objeto is not None:
                conferir_porte(servico, porte_do_objeto(atendimento.objeto))
            atendimento.servico = servico
        else:
            servico = Servico.objects.get(pk=atendimento.servico_id)

        total_esperado = conferir_total_da_cobranca(servico.preco, desconto, acrescimo, pagamentos, credito_aplicado)

        # Só com objeto há cliente para as transações de crédito; no avulso
        # elas já foram barradas acima.
        cliente_id = atendimento.objeto.cliente_id if not atendimento.avulso else None
        saldo_service = SaldoService()

        if credito_aplicado > Decimal('0'):
            saldo_service.aplicar_credito(cliente_id, credito_aplicado, atendimento.pk)

        atendimento.desconto = desconto
        atendimento.acrescimo = acrescimo
        atendimento.acrescimo_motivo = acrescimo_motivo
        atendimento.pago = True
        atendimento.save(update_fields=['servico', 'desconto', 'acrescimo', 'acrescimo_motivo', 'pago'])

        # a comissão do parceiro congela aqui (ver agenda)
        colaborador = atendimento.colaborador
        atendimento.pagamentos.all().delete()
        PagamentoAtendimento.objects.bulk_create([
            PagamentoAtendimento(
                atendimento=atendimento, forma=p['forma'], valor=p['valor'],
                comissao_percentual=colaborador.comissao_percentual if colaborador and colaborador.eh_parceiro else None,
                repasse=colaborador.comissao_para(p['valor']) if colaborador else Decimal('0.00'),
            )
            for p in pagamentos
        ])

        if troco_credito > Decimal('0'):
            saldo_service.adicionar_troco(cliente_id, troco_credito, atendimento.pk)

        # o app do cliente passa a mostrar o que foi cobrado de verdade
        self._notificar_cobranca(atendimento, servico, total_esperado)
        return atendimento

    def desfazer_cobranca(self, atendimento: AtendimentoKanban) -> AtendimentoKanban:
        """Volta o card a não pago: apaga os pagamentos e as transações de
        crédito da cobrança e zera desconto e acréscimo. A troca de serviço
        fica — ela registra o que foi feito, não como foi pago — e o app do
        cliente volta a ver o preço do serviço, sem acréscimo."""
        from apps_work.financeiro.models import TransacaoCredito
        from apps_work.servicos.models import Servico

        TransacaoCredito.objects.filter(atendimento_kanban=atendimento).delete()
        atendimento.pagamentos.all().delete()
        atendimento.pago = False
        atendimento.desconto = Decimal('0')
        atendimento.acrescimo = Decimal('0')
        atendimento.acrescimo_motivo = ''
        atendimento.save(update_fields=['pago', 'desconto', 'acrescimo', 'acrescimo_motivo'])

        servico = Servico.objects.get(pk=atendimento.servico_id)
        self._notificar_cobranca(atendimento, servico, servico.preco)
        return atendimento

    def _notificar_cobranca(self, atendimento: AtendimentoKanban, servico, valor_total: Decimal) -> None:
        from apps_work.financeiro.services import notificar_cobranca, snapshot_do_servico

        notificar_cobranca(
            AtendimentoKanban, OrigemAtendimento.KANBAN, atendimento.pk, valor_total,
            atendimento.acrescimo, atendimento.acrescimo_motivo, [snapshot_do_servico(servico)],
        )

    def marcar_falta(self, atendimento: AtendimentoKanban) -> AtendimentoKanban:
        """Registra que o cliente não apareceu.

        Recusa atendimento já pago: o dinheiro está no caixa e marcar falta o
        deixaria contabilizado como receita de um serviço que não houve. Quem
        cobrou por engano desfaz a cobrança primeiro.
        """
        if atendimento.pago:
            raise ValidationError(ERRO_FALTA_EM_PAGO)

        atendimento.faltou = True
        atendimento.save(update_fields=['faltou'])
        self._notificar_falta(atendimento)
        return atendimento

    def desfazer_falta(self, atendimento: AtendimentoKanban) -> AtendimentoKanban:
        atendimento.faltou = False
        atendimento.save(update_fields=['faltou'])
        self._notificar_falta(atendimento)
        return atendimento

    def _notificar_falta(self, atendimento: AtendimentoKanban) -> None:
        from django.db import connection
        from .signals import atendimento_kanban_falta_alterada

        atendimento_kanban_falta_alterada.send(
            sender=AtendimentoKanban,
            schema_name=connection.schema_name,
            atendimento_id=atendimento.pk,
            faltou=atendimento.faltou,
        )


class CapacidadeService:
    """Quanto cabe num dia da esteira, e o que já está ocupado.

    Dois números por dia, do horário de funcionamento da semana ou do
    AjusteDoDia da data: a `capacidade` (o máximo de atendimentos no dia, com
    ou sem hora; nulo é sem máximo) e as `vagas` (quantos andam juntos). Um
    horário só entra na grade se couber nos dois.

    A ocupação é lida do quadro, não só da previsão: o card segura a vaga até
    chegar na etapa de pronto, mesmo passado o tempo previsto, e o atendimento
    sem hora ocupa a partir do momento em que foi lançado. É isso que impede a
    cascata — vender um horário em cima de um atraso que só o pátio conhece.
    """

    def limites(self, data: date) -> dict:
        """{'capacidade', 'vagas', 'ajustado'}: o ajuste da data, se houver,
        senão o horário do dia da semana; dia sem horário cabe 1 por vez."""
        from apps_work.empresa.models import HorarioFuncionamento

        ajuste = AjusteDoDia.objects.filter(data=data).first()
        if ajuste is not None:
            return {'capacidade': ajuste.capacidade, 'vagas': ajuste.vagas, 'ajustado': True}
        horario = HorarioFuncionamento.objects.filter(dia=data.weekday()).first()
        if horario is None:
            return {'capacidade': None, 'vagas': 1, 'ajustado': False}
        return {'capacidade': horario.capacidade, 'vagas': horario.vagas, 'ajustado': False}

    def do_dia(self, data: date) -> dict:
        """Os limites do dia e quantos atendimentos já há nele (quem faltou
        não conta: a vaga voltou)."""
        return {'data': data, **self.limites(data), 'ocupados': self._atendimentos_do_dia(data).count()}

    def ajustar(self, data: date, capacidade: int | None, vagas: int) -> dict:
        if vagas < 1:
            raise ErroDeNegocio('Cabe pelo menos 1 atendimento ao mesmo tempo.', 'invalido')
        if capacidade is not None and capacidade < 1:
            raise ErroDeNegocio('O máximo do dia é de pelo menos 1 atendimento.', 'invalido')
        AjusteDoDia.objects.update_or_create(data=data, defaults={'capacidade': capacidade, 'vagas': vagas})
        return self.do_dia(data)

    def desfazer_ajuste(self, data: date) -> dict:
        AjusteDoDia.objects.filter(data=data).delete()
        return self.do_dia(data)

    def lotado(self, data: date, excluir_id: int | None = None) -> bool:
        capacidade = self.limites(data)['capacidade']
        if capacidade is None:
            return False
        return self._atendimentos_do_dia(data).exclude(pk=excluir_id).count() >= capacidade

    def travar_dia(self, data: date) -> None:
        """Serializa quem confere a vaga do mesmo dia deste negócio até o fim
        da transação: dois lançamentos ao mesmo tempo não enxergam o dia sem o
        outro e passam os dois pela última vaga. Fora de transação não trava
        nada (o Postgres solta na hora), por isso quem confere e grava faz os
        dois dentro de um `atomic()`."""
        with connection.cursor() as cursor:
            cursor.execute(
                'SELECT pg_advisory_xact_lock(hashtext(%s))', [f'{connection.schema_name}:{data.isoformat()}'],
            )

    def conferir(
        self,
        data: date,
        duracao_minutos: int,
        horario_entrada: time | None,
        excluir_id: int | None = None,
        conferir_dia: bool = True,
    ) -> None:
        """A trava do dono: o dia lotado (`dia_lotado`) e, com hora marcada, a
        hora em que o negócio está fechado (`horario_bloqueado`, antes de
        olhar as vagas) e a hora sem vaga (`horario_ocupado`). `excluir_id` é
        o próprio atendimento quando ele está sendo remarcado;
        `conferir_dia=False` é a remarcação dentro do mesmo dia, que já tem a
        sua vaga nele e só confere a hora."""
        self.travar_dia(data)
        if conferir_dia and self.lotado(data, excluir_id):
            info = self.do_dia(data)
            raise ErroDeNegocio(
                f"O dia já está no limite: {info['ocupados']} de {info['capacidade']} atendimentos.", 'dia_lotado',
            )
        if horario_entrada is None:
            return
        self.conferir_bloqueio(data, duracao_minutos, horario_entrada)
        inicio, fim = self._intervalo_pedido(data, duracao_minutos, horario_entrada)
        ocupados = self.ocupacoes(data, excluir_id)
        if not cabe(inicio, fim, ocupados, self.limites(data)['vagas']):
            raise ValidationError(ERRO_HORARIO_OCUPADO)

    def conferir_bloqueio(self, data: date, duracao_minutos: int, horario_entrada: time | None) -> None:
        """A hora pedida não pode encostar num trecho em que o negócio está
        fechado (Bloqueio sem colaborador, da agenda): 400 `horario_bloqueado`.
        Diferente do limite, isto não tem ignorar — para receber ali, o dono
        exclui o bloqueio antes. Sem hora não há o que conferir: o card sem
        hora continua entrando (um avulso que chegou), só não entra na grade."""
        if horario_entrada is None:
            return
        from apps_work.agenda.services import BloqueioService

        inicio, fim = self._intervalo_pedido(data, duracao_minutos, horario_entrada)
        for inicio_bl, fim_bl in BloqueioService().intervalos_do_negocio(data):
            if inicio < fim_bl and inicio_bl < fim:
                raise ErroDeNegocio(ERRO_HORARIO_BLOQUEADO['detail'], ERRO_HORARIO_BLOQUEADO['code'])

    def _intervalo_pedido(self, data: date, duracao_minutos: int, horario_entrada: time) -> Intervalo:
        inicio = datetime.combine(data, horario_entrada.replace(second=0, microsecond=0))
        return inicio, inicio + timedelta(minutes=duracao_minutos or DURACAO_PADRAO_MINUTOS)

    def livres(
        self,
        data: date,
        duracao_minutos: int,
        nao_antes_de: datetime | None = None,
        excluir_id: int | None = None,
    ) -> list[datetime]:
        """Os inícios em que um atendimento desta duração cabe no dia, no
        horário local e sem fuso. Dia fechado ou lotado não tem nenhum.
        `excluir_id` é o card que está sendo remarcado: a grade não o conta,
        senão ele barraria a si mesmo."""
        from apps_work.empresa.models import HorarioFuncionamento

        horario = HorarioFuncionamento.objects.filter(dia=data.weekday(), ativo=True).first()
        if not horario or not horario.abertura or not horario.fechamento or self.lotado(data, excluir_id):
            return []
        return inicios_livres(
            datetime.combine(data, horario.abertura),
            datetime.combine(data, horario.fechamento),
            timedelta(minutes=duracao_minutos or DURACAO_PADRAO_MINUTOS),
            self.ocupacoes(data, excluir_id),
            self.limites(data)['vagas'],
            nao_antes_de,
        )

    def ocupacoes(self, data: date, excluir_id: int | None = None) -> list[Intervalo]:
        """O que ocupa vaga no dia, como intervalos locais sem fuso.

        Cada atendimento ocupa da entrada (a hora marcada ou, sem ela, a hora em
        que foi lançado, se foi lançado no próprio dia) até o maior entre o fim
        previsto e agora, enquanto não chega na etapa de pronto; chegando, até a
        hora em que chegou.

        Os trechos em que o negócio está fechado (Bloqueio sem colaborador, da
        agenda) entram repetidos `vagas` vezes: ocupam todas as vagas, e a
        grade não oferece nada ali. O fim de cada um vira início oferecido,
        como o de qualquer ocupação (acabou o almoço às 13:00, o 13:00 entra).
        """
        from apps_work.agenda.services import BloqueioService

        # "agora" arredondado para a próxima marca da grade: o fim de uma
        # ocupação vira início oferecido, e 10:37:12 não é hora de ninguém
        agora = proxima_marca(timezone.localtime().replace(tzinfo=None))
        hoje = timezone.localdate()
        intervalos = []
        for a in self._atendimentos_do_dia(data).exclude(pk=excluir_id).select_related('servico'):
            if a.horario_entrada is not None:
                inicio = datetime.combine(data, a.horario_entrada).replace(second=0, microsecond=0)
            else:
                lancado = timezone.localtime(a.criado_em).replace(tzinfo=None, second=0, microsecond=0)
                if lancado.date() != data:
                    continue
                inicio = lancado
            fim = inicio + timedelta(minutes=a.duracao_prevista)
            if a.pronto_em is not None:
                fim = max(inicio, timezone.localtime(a.pronto_em).replace(tzinfo=None, second=0, microsecond=0))
            elif data == hoje:
                fim = max(fim, agora)
            intervalos.append((inicio, fim))
        vagas = self.limites(data)['vagas']
        for bloqueado in BloqueioService().intervalos_do_negocio(data):
            intervalos.extend([bloqueado] * vagas)
        return intervalos

    def _atendimentos_do_dia(self, data: date):
        return AtendimentoKanban.objects.filter(data=data, faltou=False)


class SlotService:
    """A grade de horas de entrada do dia, no formato da grade da agenda."""

    def gerar_slots(self, data: date, servico_id: int | None = None, excluir_id: int | None = None) -> list[dict]:
        """Sem serviço, 30 minutos. Serviço que não existe é 404: cair em
        silêncio nos 30 minutos mostraria horas em que o serviço de verdade
        não cabe."""
        from apps_work.servicos.models import Servico

        duracao = DURACAO_PADRAO_MINUTOS
        if servico_id is not None:
            duracao = Servico.objects.filter(pk=servico_id).values_list('duracao', flat=True).first()
            if duracao is None:
                raise ErroDeNegocio('Serviço não encontrado.', 'nao_encontrado', 404)
        return [
            {'horario': inicio.strftime('%H:%M'), 'disponivel': True}
            for inicio in CapacidadeService().livres(data, duracao, excluir_id=excluir_id)
        ]
