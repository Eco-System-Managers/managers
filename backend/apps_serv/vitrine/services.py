import logging
from collections import defaultdict
from datetime import date, datetime, timedelta
from decimal import Decimal

from django.db import transaction
from django.utils import timezone
from django_tenants.utils import schema_context

from apps_serv.identidade import cliente_do_consumidor
from apps_serv.vitrine.models import NegocioPublico
from core.excecoes import ErroDeNegocio

logger = logging.getLogger(__name__)


class CrossTenantQueryService:

    def listar_servicos(self, schema_name: str) -> list:
        with schema_context(schema_name):
            from apps_work.servicos.models import Servico
            return [
                {
                    'id': s.id,
                    'nome': s.nome,
                    'descricao': s.descricao,
                    'duracao': s.duracao,
                    'preco': s.preco,
                    'taxa_cancelamento': s.calcular_taxa_cancelamento(),
                }
                for s in Servico.objects.filter(ativo=True)
            ]

    def listar_colaboradores(self, schema_name: str) -> list:
        with schema_context(schema_name):
            from apps_work.usuarios.models import Colaborador
            colaboradores = (
                Colaborador.objects
                .filter(ativo=True)
                .select_related('user')
                .order_by('role')
            )
            return [
                {
                    'id': c.id,
                    'nome': c.user.get_full_name() or c.user.username,
                    'funcao': c.funcao,
                    'role': c.role,
                }
                for c in colaboradores
            ]

    def listar_horarios(self, schema_name: str) -> list:
        with schema_context(schema_name):
            from apps_work.empresa.models import HorarioFuncionamento
            horarios_map = {h.dia: h for h in HorarioFuncionamento.objects.all()}
            return [
                {
                    'dia': dia,
                    'ativo': horarios_map[dia].ativo if dia in horarios_map else False,
                    'abertura': str(horarios_map[dia].abertura)[:5] if dia in horarios_map and horarios_map[dia].abertura else None,
                    'fechamento': str(horarios_map[dia].fechamento)[:5] if dia in horarios_map and horarios_map[dia].fechamento else None,
                }
                for dia in range(7)
            ]

    def status_kanban(self, schema_name: str, atendimento_ids: list[int]) -> dict[int, dict]:
        """Lê a etapa atual de cada atendimento no schema do negócio e devolve
        {atendimento_id: {'status_kanban': ..., 'etapa_nome': ...}}."""
        if not atendimento_ids:
            return {}

        with schema_context(schema_name):
            from apps_work.kanban.models import AtendimentoKanban
            from apps_work.kanban.services import StatusClienteService

            status_por_etapa = StatusClienteService().mapa_por_etapa()
            atendimentos = (
                AtendimentoKanban.objects
                .filter(id__in=atendimento_ids)
                .select_related('etapa')
            )
            return {
                a.id: {
                    'status_kanban': status_por_etapa.get(a.etapa_id),
                    'etapa_nome': a.etapa.nome,
                }
                for a in atendimentos
            }

    def listar_disponibilidade(self, schema_name: str, data: date, servico_ids: list, colaborador_id: int = None) -> list:
        with schema_context(schema_name):
            from apps_work.empresa.models import EmpresaConfig, HorarioFuncionamento
            from apps_work.agenda.models import Agendamento
            from apps_work.servicos.models import Servico

            config = EmpresaConfig.objects.filter(pk=1).first()
            if config and config.tipo_agenda == 'kanban':
                from apps_work.kanban.services import SlotService
                resultado = SlotService().gerar_slots(data)
                return [
                    datetime.combine(
                        data, datetime.strptime(slot['horario'], '%H:%M').time(),
                        tzinfo=timezone.get_current_timezone(),
                    ).isoformat()
                    for slot in resultado if slot['disponivel']
                ]

            dia_semana = data.weekday()

            try:
                horario = HorarioFuncionamento.objects.get(dia=dia_semana, ativo=True)
            except HorarioFuncionamento.DoesNotExist:
                return []

            if not horario.abertura or not horario.fechamento:
                return []

            servicos = Servico.objects.filter(id__in=servico_ids, ativo=True)
            if not servicos.exists():
                return []

            duracao_total = sum(s.duracao for s in servicos)

            inicio = datetime.combine(data, horario.abertura, tzinfo=timezone.get_current_timezone())
            fim = datetime.combine(data, horario.fechamento, tzinfo=timezone.get_current_timezone())

            agendamentos_qs = Agendamento.objects.filter(
                data_hora__date=data,
                status__in=['agendado', 'confirmado'],
            )
            if colaborador_id:
                agendamentos_qs = agendamentos_qs.filter(colaborador_id=colaborador_id)
            agendamentos = agendamentos_qs.prefetch_related('servicos__servico')

            ocupados = []
            for ag in agendamentos:
                duracao_ag = sum(s.servico.duracao for s in ag.servicos.all())
                ocupados.append((ag.data_hora, ag.data_hora + timedelta(minutes=duracao_ag)))

            slots = []
            slot_atual = inicio
            intervalo = timedelta(minutes=30)

            while slot_atual + timedelta(minutes=duracao_total) <= fim:
                fim_slot = slot_atual + timedelta(minutes=duracao_total)
                conflito = any(
                    not (fim_slot <= ini_oc or slot_atual >= fim_oc)
                    for ini_oc, fim_oc in ocupados
                )
                if not conflito:
                    slots.append(slot_atual.isoformat())
                slot_atual += intervalo

            return slots


class StatusKanbanAgendamentosService:
    """Descobre em que ponto do quadro está cada atendimento de kanban de uma
    lista de agendamentos do consumidor. Agrupa por negócio para trocar de
    schema uma vez por tenant, e não uma vez por agendamento."""

    def por_agendamento(self, agendamentos: list) -> dict[int, dict]:
        ids_por_schema: dict[str, list[int]] = defaultdict(list)
        for ag in agendamentos:
            # 'faltou' fica de fora junto com 'cancelado': os dois já são
            # desfecho final e não dependem da coluna atual do quadro.
            if ag.origem == 'kanban' and ag.status not in ('cancelado', 'faltou'):
                ids_por_schema[ag.schema_name].append(ag.agendamento_id)

        if not ids_por_schema:
            return {}

        consulta = CrossTenantQueryService()
        status_por_schema: dict[str, dict[int, dict]] = {}
        for schema_name, ids in ids_por_schema.items():
            try:
                status_por_schema[schema_name] = consulta.status_kanban(schema_name, ids)
            except Exception:
                # Um negócio indisponível (schema removido, erro de conexão) não
                # pode derrubar a agenda inteira do consumidor — os outros
                # agendamentos continuam sendo exibidos, esse fica sem status.
                logger.warning('Falha ao ler status do kanban', extra={'schema_name': schema_name}, exc_info=True)

        return {
            ag.id: status_por_schema[ag.schema_name][ag.agendamento_id]
            for ag in agendamentos
            if ag.schema_name in status_por_schema
            and ag.agendamento_id in status_por_schema[ag.schema_name]
        }


class AgendamentoTenantService:
    """Cria e cancela agendamentos no schema do tenant, em sincronia com o schema público."""

    def criar(self, schema_name: str, consumidor, servico_ids: list, data_hora: datetime, colaborador_id: int = None, objeto_id: int = None):
        from apps_serv.consumidores.models import AgendamentoConsumidor

        negocio = NegocioPublico.objects.get(schema_name=schema_name)
        origem = 'kanban' if negocio.tipo_agenda == 'kanban' else 'agenda'

        with transaction.atomic():
            # Resolver objeto antes de entrar no schema do tenant
            objeto_dados = None
            if objeto_id:
                from apps_serv.consumidores.models import ObjetoConsumidor
                try:
                    obj = ObjetoConsumidor.objects.get(id=objeto_id, consumidor=consumidor)
                    objeto_dados = {'tipo': obj.tipo, 'nome_exibicao': obj.nome_exibicao, **obj.dados}
                except ObjetoConsumidor.DoesNotExist:
                    raise ErroDeNegocio('Objeto não encontrado.', 'objeto_nao_encontrado')

            if origem == 'kanban' and not objeto_dados:
                raise ErroDeNegocio('Selecione um pet ou veículo para agendar.', 'objeto_obrigatorio')

            with schema_context(schema_name):
                from apps_work.servicos.models import Servico
                from apps_work.clientes.models import Cliente

                servicos = list(Servico.objects.filter(id__in=servico_ids, ativo=True))
                if not servicos:
                    raise ErroDeNegocio('Nenhum serviço válido encontrado.', 'servico_invalido')

                valor_total = sum(s.preco for s in servicos)
                duracao_total = sum(s.duracao for s in servicos)
                valor_taxa_cancelamento = sum(s.calcular_taxa_cancelamento() for s in servicos)

                cliente = cliente_do_consumidor(consumidor)
                if cliente is None:
                    cliente = Cliente.objects.create(
                        nome=consumidor.nome,
                        email=consumidor.email,
                        telefone=consumidor.telefone,
                        origem=Cliente.ORIGEM_SERVICEMANAGE,
                        consumidor_id=consumidor.id,
                    )

                profissional_nome = ''

                if origem == 'kanban':
                    agendamento_id = self._criar_atendimento_kanban(
                        cliente=cliente, servico=servicos[0],
                        objeto_dados=objeto_dados, data_hora=data_hora,
                    )
                else:
                    from apps_work.agenda.models import Agendamento, AgendamentoServico, Pagamento

                    agendamento = Agendamento.objects.create(
                        cliente=cliente,
                        data_hora=data_hora,
                        colaborador_id=colaborador_id,
                        status='agendado',
                    )

                    for servico in servicos:
                        AgendamentoServico.objects.create(
                            agendamento=agendamento,
                            servico=servico,
                            preco_cobrado=servico.preco,
                        )

                    Pagamento.objects.create(
                        agendamento=agendamento,
                        forma='qr_code',
                        valor=valor_total,
                    )

                    agendamento_id = agendamento.id
                    if colaborador_id:
                        try:
                            from apps_work.usuarios.models import Colaborador
                            colab = Colaborador.objects.get(id=colaborador_id)
                            profissional_nome = colab.user.get_full_name() or colab.user.username
                        except Exception:
                            pass

                servicos_snapshot = [
                    {
                        'nome': s.nome, 'duracao': s.duracao, 'preco': float(s.preco),
                        'taxa_cancelamento': float(s.calcular_taxa_cancelamento()),
                    }
                    for s in servicos
                ]

            # A conexão cliente-negócio acontece automaticamente no primeiro
            # agendamento (cria ou reativa o vínculo, sem lançar erro se já existir).
            VincularNegocioService().garantir_vinculo(schema_name, consumidor)

            agendamento_consumidor = AgendamentoConsumidor.objects.create(
                consumidor=consumidor,
                schema_name=schema_name,
                agendamento_id=agendamento_id,
                origem=origem,
                negocio_nome=negocio.nome,
                nicho=negocio.nicho,
                servicos=servicos_snapshot,
                profissional_nome=profissional_nome,
                objeto_dados=objeto_dados,
                data_hora=data_hora,
                duracao_total=duracao_total,
                valor_total=valor_total,
                valor_taxa_cancelamento=valor_taxa_cancelamento,
                status='agendado',
            )

        return agendamento_consumidor

    def _criar_atendimento_kanban(self, cliente, servico, objeto_dados: dict, data_hora: datetime) -> int:
        """Encontra ou cria o Pet/Veículo do cliente no tenant a partir do
        objeto do consumidor, e cria o atendimento na primeira etapa do
        quadro. Retorna o id do AtendimentoKanban criado."""
        from apps_work.kanban.models import EtapaKanban
        from apps_work.kanban.services import AtendimentoKanbanService

        tipo = objeto_dados.get('tipo')
        if tipo == 'veiculo':
            from apps_work.clientes.models import Veiculo
            objeto = Veiculo.objects.filter(cliente=cliente, placa=objeto_dados.get('placa', '')).first()
            if objeto is None:
                objeto = Veiculo.objects.create(
                    cliente=cliente, tipo='veiculo',
                    placa=objeto_dados.get('placa', ''),
                    marca=objeto_dados.get('marca', ''),
                    modelo=objeto_dados.get('modelo', ''),
                    cor=objeto_dados.get('cor', ''),
                )
        elif tipo == 'pet':
            from apps_work.clientes.models import Pet
            porte_map = {'pequeno': 'pequeno', 'médio': 'medio', 'grande': 'grande', 'gigante': 'gigante'}
            objeto = Pet.objects.filter(cliente=cliente, nome=objeto_dados.get('nome', '')).first()
            if objeto is None:
                objeto = Pet.objects.create(
                    cliente=cliente, tipo='pet',
                    nome=objeto_dados.get('nome', ''),
                    especie=objeto_dados.get('especie', ''),
                    raca=objeto_dados.get('raca', ''),
                    porte=porte_map.get(objeto_dados.get('porte', '').strip().lower(), ''),
                )
        else:
            raise ErroDeNegocio('Tipo de objeto inválido para agendamento por esteira.', 'objeto_invalido')

        etapa = EtapaKanban.objects.order_by('ordem').first()
        if etapa is None:
            raise ErroDeNegocio('Este negócio ainda não configurou as etapas de atendimento.', 'esteira_nao_configurada')

        atendimento = AtendimentoKanbanService().criar(
            etapa=etapa,
            objeto_id=objeto.id,
            servico_id=servico.id,
            horario_entrada=data_hora.time(),
            data=data_hora.date(),
        )
        return atendimento.id


class CancelarAgendamentoService:
    def cancelar(self, agendamento_consumidor, consumidor):
        if agendamento_consumidor.consumidor_id != consumidor.id:
            raise PermissionError('Agendamento não pertence a este consumidor.')

        if agendamento_consumidor.status == 'cancelado':
            raise ErroDeNegocio('Agendamento já cancelado.', 'agendamento_ja_cancelado')

        if agendamento_consumidor.status == 'concluido':
            raise ErroDeNegocio('Não é possível cancelar um agendamento concluído.', 'agendamento_concluido')

        dentro_prazo = self._dentro_prazo(agendamento_consumidor)
        taxa = Decimal('0') if dentro_prazo else agendamento_consumidor.valor_taxa_cancelamento

        with transaction.atomic():
            with schema_context(agendamento_consumidor.schema_name):
                if agendamento_consumidor.origem == 'kanban':
                    from apps_work.kanban.models import AtendimentoKanban
                    AtendimentoKanban.objects.filter(id=agendamento_consumidor.agendamento_id).delete()
                else:
                    from apps_work.agenda.models import Agendamento
                    Agendamento.objects.filter(id=agendamento_consumidor.agendamento_id).update(status='cancelado')

                if taxa > 0:
                    from apps_work.financeiro.services import SaldoService

                    cliente = cliente_do_consumidor(consumidor)
                    if cliente:
                        SaldoService().registrar_taxa_cancelamento(
                            cliente.id, taxa,
                            descricao=(
                                f'Cancelamento fora do prazo — agendamento de '
                                f'{agendamento_consumidor.data_hora:%d/%m/%Y %H:%M}'
                            ),
                        )

            agendamento_consumidor.status = 'cancelado'
            agendamento_consumidor.save(update_fields=['status'])

        return {'taxa': float(taxa)}

    def _dentro_prazo(self, agendamento) -> bool:
        duracao = agendamento.duracao_total
        if duracao <= 30:
            horas = 6
        elif duracao <= 90:
            horas = 12
        else:
            horas = 24

        prazo = agendamento.data_hora - timedelta(hours=horas)
        return timezone.now() <= prazo


class VincularNegocioService:
    def _sincronizar_cliente(self, schema_name: str, consumidor, evento: str, notificar: bool) -> None:
        """Espelha o perfil do consumidor no Cliente do tenant e, quando o
        vínculo muda de estado, avisa o negócio.

        A sincronização roda em todo agendamento porque é ela que propaga nome
        e telefone do cadastro único (o cadastro vive no schema público e não
        tem cópia por tenant). Já a notificação só faz sentido na transição —
        notificar sempre fazia o dono receber "fulano agora é seu cliente" a
        cada agendamento de quem já era cliente dele havia meses.

        Nunca deve quebrar o fluxo de vincular/desvincular/agendar: uma falha
        aqui é registrada e engolida.

        O `atomic()` interno cria um savepoint e é o que torna esse "engolir"
        seguro. Este método roda dentro do `atomic()` de
        AgendamentoTenantService.criar: sem o savepoint, uma falha de banco
        capturada abaixo deixaria a transação externa em estado abortado, e o
        AgendamentoConsumidor criado logo em seguida estouraria
        TransactionManagementError — o agendamento falharia inteiro depois de já
        ter gravado no schema do tenant. Com o savepoint, só o que aconteceu
        aqui dentro é desfeito.
        """
        try:
            with schema_context(schema_name):
                with transaction.atomic():
                    from apps_work.clientes.models import Cliente
                    from apps_work.notificacoes.models import Notificacao

                    cliente = cliente_do_consumidor(consumidor)

                    if evento == 'vinculado':
                        if cliente is None:
                            cliente = Cliente.objects.create(
                                nome=consumidor.nome, email=consumidor.email,
                                telefone=consumidor.telefone, visivel=True,
                                origem=Cliente.ORIGEM_SERVICEMANAGE,
                                consumidor_id=consumidor.id,
                            )
                        else:
                            # O vínculo passa a posse do cadastro pro consumidor,
                            # mesmo que o negócio o tenha criado na mão antes. Sem
                            # marcar a origem, remover pelo painel apagaria a linha
                            # e deixaria o vínculo ativo no público.
                            cliente.nome = consumidor.nome
                            cliente.telefone = consumidor.telefone
                            cliente.visivel = True
                            cliente.origem = Cliente.ORIGEM_SERVICEMANAGE
                            cliente.save(update_fields=['nome', 'telefone', 'visivel', 'origem'])
                        tipo, titulo = 'cliente_vinculado', f'{consumidor.nome} agora é seu cliente'
                    else:
                        if cliente:
                            cliente.visivel = False
                            cliente.save(update_fields=['visivel'])
                        tipo, titulo = 'cliente_desvinculado', f'{consumidor.nome} não é mais seu cliente'

                    if notificar:
                        Notificacao.objects.create(tipo=tipo, titulo=titulo, cliente=cliente)
        except Exception:
            logger.warning(
                'Falha ao sincronizar o cliente do consumidor no tenant',
                extra={'schema_name': schema_name, 'evento': evento},
                exc_info=True,
            )

    def garantir_vinculo(self, schema_name: str, consumidor):
        """Cria ou reativa o vínculo sem lançar erro se já estiver ativo — usado
        como efeito colateral automático de todo agendamento."""
        from apps_serv.consumidores.models import VinculoConsumidor

        vinculo_existente = VinculoConsumidor.objects.filter(
            consumidor=consumidor, schema_name=schema_name
        ).first()

        # Só é novidade pro negócio quando o vínculo nasce ou volta a existir;
        # agendamento de quem já é cliente não gera aviso.
        houve_transicao = True

        if vinculo_existente:
            houve_transicao = not vinculo_existente.ativo
            if not vinculo_existente.ativo:
                vinculo_existente.ativo = True
                vinculo_existente.desvinculado_em = None
                vinculo_existente.save(update_fields=['ativo', 'desvinculado_em'])
        else:
            vinculo_existente = VinculoConsumidor.objects.create(consumidor=consumidor, schema_name=schema_name)

        self._sincronizar_cliente(schema_name, consumidor, 'vinculado', notificar=houve_transicao)
        return vinculo_existente

    def vincular(self, schema_name: str, consumidor):
        from apps_serv.consumidores.models import VinculoConsumidor

        vinculo_existente = VinculoConsumidor.objects.filter(
            consumidor=consumidor, schema_name=schema_name
        ).first()

        if vinculo_existente:
            if vinculo_existente.ativo:
                raise ErroDeNegocio('Você já está vinculado a este negócio.', 'vinculo_existente')
            # Reativar vínculo anterior (consumidor havia se desvinculado)
            vinculo_existente.ativo = True
            vinculo_existente.desvinculado_em = None
            vinculo_existente.save(update_fields=['ativo', 'desvinculado_em'])
            vinculo = vinculo_existente
        else:
            vinculo = VinculoConsumidor.objects.create(
                consumidor=consumidor,
                schema_name=schema_name,
            )

        # Só chega aqui se o vínculo nasceu ou foi reativado — acima já barra
        # quem tentou vincular estando ativo. Portanto é sempre transição.
        self._sincronizar_cliente(schema_name, consumidor, 'vinculado', notificar=True)
        return vinculo

    def desvincular(self, schema_name: str, consumidor):
        from apps_serv.consumidores.models import VinculoConsumidor

        try:
            vinculo = VinculoConsumidor.objects.get(
                consumidor=consumidor, schema_name=schema_name, ativo=True
            )
        except VinculoConsumidor.DoesNotExist:
            raise ErroDeNegocio('Vínculo não encontrado.', 'vinculo_nao_encontrado')

        vinculo.ativo = False
        vinculo.desvinculado_em = timezone.now()
        vinculo.save(update_fields=['ativo', 'desvinculado_em'])

        # Desvincular só passa daqui se havia vínculo ativo — sempre transição.
        self._sincronizar_cliente(schema_name, consumidor, 'desvinculado', notificar=True)


_NICHO_TIPO_OBJETO = {
    'lava_rapido': 'veiculo',
    'banho_tosa': 'pet',
}


class SincronizarVitrineService:
    def sincronizar(self, schema_name: str, empresa_config) -> None:
        if not self._pode_publicar(empresa_config):
            NegocioPublico.objects.filter(schema_name=schema_name).update(ativo=False)
            return

        NegocioPublico.objects.update_or_create(
            schema_name=schema_name,
            defaults={
                'nome': empresa_config.nome,
                'nicho': empresa_config.nicho,
                'tipo_agenda': empresa_config.tipo_agenda,
                'tipo_objeto': _NICHO_TIPO_OBJETO.get(empresa_config.nicho),
                'cidade': empresa_config.cidade or '',
                'latitude': empresa_config.latitude,
                'longitude': empresa_config.longitude,
                'logo_url': empresa_config.logo_url or '',
                'ativo': True,
            },
        )

    def _pode_publicar(self, empresa_config) -> bool:
        return (
            empresa_config.onboarding_concluido
            and empresa_config.nome
            and empresa_config.nicho
            and empresa_config.latitude is not None
            and empresa_config.longitude is not None
        )
