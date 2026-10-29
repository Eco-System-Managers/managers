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
from tenants.models import Membro
from apps_work.agenda.models import FormaPagamento, OrigemAtendimento, StatusAgendamento
from apps_work.clientes.models import OrigemCliente, TipoObjeto
from apps_work.clientes.validators import normalizar_porte
from apps_work.empresa.models import TipoAgenda
from apps_work.notificacoes.models import TipoNotificacao


def _dinheiro(valor) -> str:
    """Valor monetário no formato da API: string com duas casas ("12.50")."""
    return str(Decimal(str(valor)).quantize(Decimal('0.01')))


# O que o cliente pode marcar pelo app. A empresa, pelo Work Manage, não tem
# nenhum dos dois: marca retorno distante e atende quem chegou na hora.
ANTECEDENCIA_MINIMA = timedelta(minutes=30)
LIMITE_DIAS = 30


def _nao_antes_de() -> datetime:
    """O primeiro início que o cliente pode marcar, no horário local e sem fuso
    (o formato da grade). Vem do relógio do servidor, não do celular."""
    return (timezone.localtime() + ANTECEDENCIA_MINIMA).replace(tzinfo=None)


def _ultima_data() -> date:
    return timezone.localdate() + timedelta(days=LIMITE_DIAS)


def _conferir_janela_do_cliente(data_hora: datetime) -> None:
    """A antecedência mínima e o limite de dias, nos dois modos de agenda."""
    local = timezone.localtime(data_hora).replace(tzinfo=None)
    if local < _nao_antes_de():
        raise ErroDeNegocio(
            'Escolha um horário com pelo menos 30 minutos de antecedência.', 'antecedencia_minima',
        )
    if local.date() > _ultima_data():
        raise ErroDeNegocio(f'Dá para agendar até {LIMITE_DIAS} dias à frente.', 'fora_do_limite')


def _conferir_colaborador(colaborador_id: int | None) -> None:
    """No modo horário a agenda é individual: sem profissional ativo não há
    grade nem conflito a conferir. Roda dentro do schema do negócio."""
    from apps_work.usuarios.models import Colaborador

    if not colaborador_id:
        raise ErroDeNegocio('Escolha o profissional.', 'colaborador_obrigatorio')
    if not Colaborador.objects.filter(pk=colaborador_id, ativo=True).exists():
        raise ErroDeNegocio('Profissional não encontrado.', 'colaborador_invalido')

logger = logging.getLogger(__name__)


class CrossTenantQueryService:

    def listar_servicos(self, schema_name: str) -> list:
        with schema_context(schema_name):
            from apps_work.servicos.models import Servico
            return [
                {
                    'id': s.id,
                    'nome': s.nome,
                    # A pasta do serviço: o app do cliente agrupa por ela.
                    'nicho': s.nicho,
                    'descricao': s.descricao,
                    'duracao': s.duracao,
                    # Dinheiro sai como string, como nos serializers ("12.50"):
                    # Decimal cru viraria número (float) no JSON.
                    'preco': _dinheiro(s.preco),
                    'taxa_cancelamento': _dinheiro(s.calcular_taxa_cancelamento()),
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
                # O papel vem do Membro (schema público), anotado na consulta.
                .annotate(papel=Membro.papel_subquery(schema_name))
                .order_by('papel')
            )
            return [
                {
                    'id': c.id,
                    'nome': c.nome_exibido,
                    'funcao': c.funcao,
                    'papel': c.papel,
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
        """Os inícios que o cliente pode marcar no dia, em ISO com fuso.

        Já descontam a antecedência mínima; depois do limite de dias a lista vem
        vazia. No modo horário é a mesma grade do Work Manage (`SlotsAgendaService`).
        """
        if data > _ultima_data():
            return []

        fuso = timezone.get_current_timezone()
        nao_antes_de = _nao_antes_de()

        with schema_context(schema_name):
            from apps_work.empresa.models import EmpresaConfig
            from apps_work.servicos.models import Servico

            config = EmpresaConfig.objects.filter(pk=1).first()
            if config and config.tipo_agenda == TipoAgenda.KANBAN:
                from apps_work.kanban.services import SlotService
                inicios = [
                    datetime.combine(data, datetime.strptime(slot['horario'], '%H:%M').time())
                    for slot in SlotService().gerar_slots(data) if slot['disponivel']
                ]
                return [i.replace(tzinfo=fuso).isoformat() for i in inicios if i >= nao_antes_de]

            from apps_work.agenda.services import SlotsAgendaService

            _conferir_colaborador(colaborador_id)

            servicos = list(Servico.objects.filter(id__in=servico_ids, ativo=True))
            if not servicos:
                return []

            inicios = SlotsAgendaService().livres(
                data, colaborador_id, sum(s.duracao for s in servicos), nao_antes_de,
            )
            return [i.replace(tzinfo=fuso).isoformat() for i in inicios]


class StatusKanbanAgendamentosService:
    """Descobre em que ponto do quadro está cada atendimento de kanban de uma
    lista de agendamentos do consumidor. Agrupa por negócio para trocar de
    schema uma vez por tenant, e não uma vez por agendamento."""

    def por_agendamento(self, agendamentos: list) -> dict[int, dict]:
        ids_por_schema: dict[str, list[int]] = defaultdict(list)
        for ag in agendamentos:
            # Faltou fica de fora junto com cancelado: os dois já são
            # desfecho final e não dependem da coluna atual do quadro.
            if ag.origem == OrigemAtendimento.KANBAN and ag.status not in (StatusAgendamento.CANCELADO, StatusAgendamento.FALTOU):
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
        origem = OrigemAtendimento.KANBAN if negocio.tipo_agenda == TipoAgenda.KANBAN else OrigemAtendimento.AGENDA

        _conferir_janela_do_cliente(data_hora)

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

            if origem == OrigemAtendimento.KANBAN and not objeto_dados:
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

                if origem == OrigemAtendimento.AGENDA:
                    _conferir_colaborador(colaborador_id)
                    self._conferir_horario_livre(data_hora, colaborador_id, duracao_total)

                cliente = cliente_do_consumidor(consumidor)
                if cliente is None:
                    cliente = Cliente.objects.create(
                        nome=consumidor.nome,
                        email=consumidor.email,
                        telefone=consumidor.telefone,
                        origem=OrigemCliente.SERVICEMANAGE,
                        consumidor_id=consumidor.id,
                    )

                profissional_nome = ''

                if origem == OrigemAtendimento.KANBAN:
                    agendamento_id = self._criar_atendimento_kanban(
                        cliente=cliente, servico=servicos[0],
                        objeto_dados=objeto_dados, data_hora=data_hora,
                    )
                else:
                    from apps_work.agenda.models import Agendamento, AgendamentoServico, PagamentoAgendamento

                    agendamento = Agendamento.objects.create(
                        cliente=cliente,
                        data_hora=data_hora,
                        colaborador_id=colaborador_id,
                        status=StatusAgendamento.AGENDADO,
                    )

                    for servico in servicos:
                        AgendamentoServico.objects.create(
                            agendamento=agendamento,
                            servico=servico,
                            preco_cobrado=servico.preco,
                        )

                    PagamentoAgendamento.objects.create(
                        agendamento=agendamento,
                        forma=FormaPagamento.QR_CODE,
                        valor=valor_total,
                    )

                    agendamento_id = agendamento.id
                    if colaborador_id:
                        from apps_work.usuarios.models import Colaborador
                        colab = Colaborador.objects.select_related('user').filter(id=colaborador_id).first()
                        if colab is not None:
                            profissional_nome = colab.nome_exibido

                servicos_snapshot = [
                    {
                        'nome': s.nome, 'nicho': s.nicho, 'duracao': s.duracao, 'preco': _dinheiro(s.preco),
                        'taxa_cancelamento': _dinheiro(s.calcular_taxa_cancelamento()),
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
                servicos=servicos_snapshot,
                profissional_nome=profissional_nome,
                objeto_dados=objeto_dados,
                data_hora=data_hora,
                duracao_total=duracao_total,
                valor_total=valor_total,
                valor_taxa_cancelamento=valor_taxa_cancelamento,
                status=StatusAgendamento.AGENDADO,
            )

        return agendamento_consumidor

    def _conferir_horario_livre(self, data_hora: datetime, colaborador_id: int, duracao_minutos: int) -> None:
        """O horário pedido precisa estar na grade que o cliente viu. Uma
        conferência só cobre expediente, conflito com outro cliente e
        antecedência — a lista é a regra, e não só uma sugestão da tela."""
        from apps_work.agenda.services import SlotsAgendaService

        local = timezone.localtime(data_hora).replace(tzinfo=None)
        livres = SlotsAgendaService().livres(local.date(), colaborador_id, duracao_minutos, _nao_antes_de())
        if local not in livres:
            raise ErroDeNegocio('Esse horário não está mais livre. Escolha outro.', 'horario_indisponivel')

    def _criar_atendimento_kanban(self, cliente, servico, objeto_dados: dict, data_hora: datetime) -> int:
        """Encontra ou cria o Pet/Veículo do cliente no tenant a partir do
        objeto do consumidor, e cria o atendimento na primeira etapa do
        quadro. Retorna o id do AtendimentoKanban criado."""
        from apps_work.kanban.models import EtapaKanban
        from apps_work.kanban.services import AtendimentoKanbanService

        tipo = objeto_dados.get('tipo')
        if tipo == TipoObjeto.VEICULO:
            from apps_work.clientes.models import Veiculo
            objeto = Veiculo.objects.filter(cliente=cliente, placa=objeto_dados.get('placa', '')).first()
            if objeto is None:
                objeto = Veiculo.objects.create(
                    cliente=cliente, tipo=TipoObjeto.VEICULO,
                    placa=objeto_dados.get('placa', ''),
                    marca=objeto_dados.get('marca', ''),
                    modelo=objeto_dados.get('modelo', ''),
                    cor=objeto_dados.get('cor', ''),
                )
        elif tipo == TipoObjeto.PET:
            from apps_work.clientes.models import Pet
            objeto = Pet.objects.filter(cliente=cliente, nome=objeto_dados.get('nome', '')).first()
            if objeto is None:
                objeto = Pet.objects.create(
                    cliente=cliente, tipo=TipoObjeto.PET,
                    nome=objeto_dados.get('nome', ''),
                    especie=objeto_dados.get('especie', ''),
                    raca=objeto_dados.get('raca', ''),
                    porte=normalizar_porte(objeto_dados.get('porte', '')),
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

        if agendamento_consumidor.status == StatusAgendamento.CANCELADO:
            raise ErroDeNegocio('Agendamento já cancelado.', 'agendamento_ja_cancelado')

        if agendamento_consumidor.status == StatusAgendamento.CONCLUIDO:
            raise ErroDeNegocio('Não é possível cancelar um agendamento concluído.', 'agendamento_concluido')

        dentro_prazo = self._dentro_prazo(agendamento_consumidor)
        taxa = Decimal('0') if dentro_prazo else agendamento_consumidor.valor_taxa_cancelamento

        with transaction.atomic():
            with schema_context(agendamento_consumidor.schema_name):
                if agendamento_consumidor.origem == OrigemAtendimento.KANBAN:
                    from apps_work.kanban.models import AtendimentoKanban
                    AtendimentoKanban.objects.filter(id=agendamento_consumidor.agendamento_id).delete()
                else:
                    from apps_work.agenda.models import Agendamento
                    Agendamento.objects.filter(id=agendamento_consumidor.agendamento_id).update(status=StatusAgendamento.CANCELADO)

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

            agendamento_consumidor.status = StatusAgendamento.CANCELADO
            agendamento_consumidor.save(update_fields=['status'])

        return {'taxa': _dinheiro(taxa)}

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

        A sincronização roda em todo agendamento porque é ela que propaga a ficha
        do cadastro único (Cliente.CAMPOS_ESPELHADOS) para o negócio. Já a notificação só faz sentido na transição —
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
                        # A ficha completa vai na hora — antes iam só nome e
                        # telefone, e o resto esperava o próximo PATCH do perfil.
                        if cliente is None:
                            cliente = Cliente(
                                email=consumidor.email, visivel=True,
                                origem=OrigemCliente.SERVICEMANAGE,
                                consumidor_id=consumidor.id,
                            )
                            cliente.espelhar(consumidor)
                            cliente.save()
                        else:
                            # O vínculo passa a posse do cadastro pro consumidor,
                            # mesmo que o negócio o tenha criado na mão antes. Sem
                            # marcar a origem, remover pelo painel apagaria a linha
                            # e deixaria o vínculo ativo no público.
                            cliente.visivel = True
                            cliente.origem = OrigemCliente.SERVICEMANAGE
                            cliente.save(update_fields=['visivel', 'origem', *cliente.espelhar(consumidor)])
                        tipo, titulo = TipoNotificacao.CLIENTE_VINCULADO, f'{consumidor.nome} agora é seu cliente'
                    else:
                        if cliente:
                            # Desfeito o vínculo, os dados pessoais saem do
                            # negócio; ficam nome, telefone e o histórico.
                            cliente.visivel = False
                            cliente.save(update_fields=['visivel', *cliente.apagar_dados_pessoais()])
                        tipo, titulo = TipoNotificacao.CLIENTE_DESVINCULADO, f'{consumidor.nome} não é mais seu cliente'

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


class SincronizarVitrineService:
    def sincronizar(self, schema_name: str, empresa_config) -> None:
        if not self._pode_publicar(empresa_config):
            NegocioPublico.objects.filter(schema_name=schema_name).update(ativo=False)
            return

        NegocioPublico.objects.update_or_create(
            schema_name=schema_name,
            defaults={
                'nome': empresa_config.nome,
                'nichos': empresa_config.nichos,
                'tipo_agenda': empresa_config.tipo_agenda,
                # A config guarda vazio no modo horário; a vitrine usa nulo.
                'tipo_objeto': empresa_config.tipo_objeto or None,
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
            and empresa_config.nichos
            and empresa_config.latitude is not None
            and empresa_config.longitude is not None
        )
