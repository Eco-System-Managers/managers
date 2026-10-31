import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/compartilhar/whatsapp.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/filtros.dart';
import 'package:managers/core/widgets/mascara_formatter.dart';
import 'package:managers/core/widgets/painel.dart';
import 'package:managers/core/widgets/selo_de_status.dart';
import 'package:managers/features/clientes/domain/entities/objeto_cliente.dart';
import 'package:managers/features/clientes/presentation/widgets/pet_form_sheet.dart';
import 'package:managers/features/clientes/presentation/widgets/veiculo_form_sheet.dart';
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:managers/features/financeiro/domain/entities/pagamento.dart';
import 'package:managers/features/financeiro/presentation/widgets/cobranca_sheet.dart';

import '../../domain/entities/atendimento_kanban.dart';
import '../../kanban_provider.dart';
import '../providers/atendimento_kanban_provider.dart';
import '../widgets/cor_da_etapa.dart';
import '../widgets/remarcar_kanban_sheet.dart';

// a ficha de um card da esteira e as ações sobre ele: mover de etapa,
// ajustar o tempo previsto, remarcar (e avisar pelo WhatsApp), cobrar e
// desfazer, marcar falta e desfazer, excluir. atrasado, mostra quem vem
// depois, para avisar. o avulso (sem cadastro) é só a identificação
class AtendimentoKanbanPage extends ConsumerStatefulWidget {
  const AtendimentoKanbanPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<AtendimentoKanbanPage> createState() =>
      _AtendimentoKanbanPageState();
}

class _AtendimentoKanbanPageState extends ConsumerState<AtendimentoKanbanPage> {
  static const _semWhatsApp =
      'Não foi possível abrir o WhatsApp. Confira se ele está instalado e '
      'tente de novo.';

  AtendimentoKanbanProvider get _provider =>
      ref.read(atendimentoKanbanProvider(widget.id));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // o cadastro do veículo ou do pet, sem o remover: ele tem este atendimento
  Future<void> _corrigirObjeto(ObjetoCliente objeto) async {
    final veiculo = objeto.veiculo;
    final mudou = veiculo != null
        ? await VeiculoFormSheet.abrir(
            context,
            clienteId: objeto.clienteId,
            veiculo: veiculo,
            permitirRemover: false,
          )
        : await PetFormSheet.abrir(
            context,
            clienteId: objeto.clienteId,
            pet: objeto.pet,
            permitirRemover: false,
          );
    if (mudou && mounted) await _provider.carregar();
  }

  // o avulso não tem comanda: cobra sem crédito e sem troco como crédito
  // (a API recusa com avulso_sem_credito). a folha oferece trocar o serviço
  // pelo que foi feito (só os que servem para o porte) e avisa quando o
  // atendimento passou do tempo do serviço
  Future<void> _cobrar(AtendimentoKanban a) async {
    final zero = Decimal.fromInt(0);
    final cobrou = await CobrancaSheet.abrir(
      context,
      atendimentoId: a.id,
      valorServicos: a.servicoPreco,
      creditoDisponivel: a.ehAvulso ? zero : _provider.saldo?.saldo ?? zero,
      permiteCredito: !a.ehAvulso,
      servicos: _provider.servicosParaTrocar,
      servicoAtualId: a.servicoId,
      servicoAtualNome: a.servicoNome,
      avisoTempo: _provider.avisoDeTempo,
      onCobrar: (params) async {
        final ok = await _provider.cobrar(params);
        return ok ? null : _provider.errorMessage;
      },
    );
    if (cobrou && mounted) {
      _provider.limparErro();
      _avisar('Cobrança registrada.');
    }
  }

  Future<void> _desfazerCobranca() async {
    final ok = await confirmar(
      context,
      titulo: 'Desfazer cobrança',
      mensagem: 'Os pagamentos saem do caixa e o crédito gerado é estornado.',
      textoConfirmar: 'Desfazer',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    await _provider.desfazerCobranca();
  }

  Future<void> _marcarFalta(AtendimentoKanban a) async {
    final ok = await confirmar(
      context,
      titulo: 'Marcar falta',
      mensagem:
          '${a.rotulo} não veio? O atendimento fica registrado '
          'como falta.',
      textoConfirmar: 'Marcar falta',
    );
    if (!ok || !mounted) return;
    await _provider.alterarFalta(true);
  }

  Future<void> _excluir(AtendimentoKanban a) async {
    final ok = await confirmar(
      context,
      titulo: 'Excluir atendimento',
      mensagem:
          'O atendimento de ${a.rotulo} sai do quadro de vez. Use '
          'para registro feito por engano.',
      textoConfirmar: 'Excluir',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    await _provider.remover();
  }

  // o tempo a mais previsto: os atalhos somam ao que já tem; "sem tempo a
  // mais" zera. é do pátio: segura a vaga por mais tempo e o preço não muda
  Future<void> _ajustarTempo(AtendimentoKanban a) async {
    final atual = a.minutosExtras;
    final hoje = atual > 0
        ? 'Hoje: ${formatarDuracao(a.servicoDuracao)} mais '
              '${formatarDuracao(atual)}.'
        : 'Previsto: ${formatarDuracao(a.servicoDuracao)}.';
    final escolha = await escolherNaFolha<int>(
      context,
      titulo: 'Ajustar tempo',
      descricao:
          'Só o tempo previsto muda, para a vaga ficar ocupada até o fim. '
          'O preço continua o mesmo. $hoje',
      opcoes: [
        for (final extra in const [15, 30, 60, 120])
          OpcaoDaFolha(
            valor: atual + extra,
            texto: '+${formatarDuracao(extra)}',
            icone: Icons.more_time_rounded,
          ),
        OpcaoDaFolha(
          valor: 0,
          texto: 'Sem tempo a mais',
          icone: Icons.timer_off_outlined,
          selecionada: atual == 0,
        ),
      ],
    );
    if (escolha == null || escolha == atual || !mounted) return;
    await _provider.ajustarTempo(escolha);
  }

  // outro dia e outra hora (ou sem hora). o dia lotado ou a hora sem vaga
  // no destino é aviso: a tela pergunta e, se a pessoa quiser, remarca
  // mesmo assim
  Future<void> _remarcar(AtendimentoKanban a) async {
    final destino = await RemarcarKanbanSheet.abrir(
      context,
      dataAtual: a.data ?? somenteData(DateTime.now()),
      horaAtual: a.horarioEntrada,
      buscarSlots: _provider.slotsParaRemarcar,
    );
    if (destino == null || !mounted) return;
    await _provider.remarcar(destino.data, destino.hora);
    if (!mounted) return;

    final aviso = _provider.limiteEstourado;
    if (aviso == null) return;
    final remarcar = await confirmar(
      context,
      titulo: 'Passa do limite',
      mensagem: '$aviso Remarcar mesmo assim?',
      textoConfirmar: 'Remarcar mesmo assim',
    );
    if (!mounted) return;
    if (remarcar) {
      await _provider.remarcar(destino.data, destino.hora, ignorarLimite: true);
    } else {
      _provider.desistirDoLimite();
    }
  }

  // o aviso da nova data pelo WhatsApp, com o texto pronto do provider
  Future<void> _avisarPeloWhatsApp(AtendimentoKanban a) async {
    final texto = _provider.textoDoAviso;
    if (texto == null) return;
    final abriu = await abrirWhatsApp(
      telefone: a.clienteTelefone,
      texto: texto,
    );
    if (!mounted) return;
    if (abriu) {
      _provider.avisoOferecido();
    } else {
      _avisar(_semWhatsApp);
    }
  }

  // o aviso do atraso para quem vem depois, pelo WhatsApp. o sistema
  // mostra; quem fala com o cliente é o dono
  Future<void> _avisarAfetado(AtendimentoKanban afetado) async {
    final texto = _provider.textoDoAtraso(afetado);
    if (texto == null) return;
    final abriu = await abrirWhatsApp(
      telefone: afetado.clienteTelefone,
      texto: texto,
    );
    if (!abriu && mounted) _avisar(_semWhatsApp);
  }

  // "sex, 25 de outubro, às 09:00" ou "sex, 25 de outubro, sem hora marcada"
  String _quando(AtendimentoKanban a) {
    final data = a.data;
    if (data == null) return 'outro dia';
    final hora = a.horarioEntrada;
    return '${formatarDataPorExtenso(data)}'
        '${hora == null ? ', sem hora marcada' : ', às ${formatarHora(hora)}'}';
  }

  // "40 min · +20 min": a duração do serviço e o tempo a mais previsto
  String? _duracaoPrevista(AtendimentoKanban a) {
    if (a.servicoDuracao <= 0 && a.minutosExtras <= 0) return null;
    final extra = a.minutosExtras > 0
        ? ' · +${formatarDuracao(a.minutosExtras)}'
        : '';
    return '${formatarDuracao(a.servicoDuracao)}$extra';
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(atendimentoKanbanProvider(widget.id));

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        if (provider.removido) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop(true);
          });
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Atendimento')),
          body: _corpo(context, provider),
        );
      },
    );
  }

  Widget _corpo(BuildContext context, AtendimentoKanbanProvider provider) {
    final a = provider.atendimento;
    if (a == null) {
      final erro = provider.erroAoCarregar;
      if (erro != null) {
        return EstadoErro(
          mensagem: erro.message,
          onTentarDeNovo: provider.carregar,
        );
      }
      return const Carregando();
    }

    final colors = Theme.of(context).colorScheme;
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final etapaAtual = provider.etapas
        .where((e) => e.id == a.etapaId)
        .firstOrNull;
    final cor = corDaEtapa(etapaAtual?.cor ?? '', colors);
    final telefone = MascaraFormatter.dinamica(MascaraFormatter.telefone)
        .aplicar(a.clienteTelefone);
    final objeto = a.objeto;
    final atraso = provider.atraso;
    final afetados = provider.afetados;

    return Column(
      children: [
        if (provider.isLoading)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: BrandSpacing.space5),
            children: [
              Padding(
                padding: const EdgeInsets.all(BrandSpacing.space5),
                child: Column(
                  children: [
                    Text(
                      a.horarioEntrada == null
                          ? 'Sem hora marcada'
                          : formatarHora(a.horarioEntrada!),
                      style: textos.headlineMedium,
                    ),
                    const SizedBox(height: BrandSpacing.space1),
                    Text(
                      a.data == null ? '' : formatarDataPorExtenso(a.data!),
                      style: textos.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    // o avulso não tem cliente: a identificação é o título
                    if (a.ehAvulso) ...[
                      const SizedBox(height: BrandSpacing.space2),
                      Text(
                        a.identificacao,
                        style: textos.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: BrandSpacing.space3),
                    Wrap(
                      spacing: BrandSpacing.space2,
                      runSpacing: BrandSpacing.space1,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          avatar: CircleAvatar(backgroundColor: cor, radius: 6),
                          label: Text(a.etapaNome),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (a.ehAvulso)
                          SeloDeStatus(
                            texto: 'Avulso',
                            cor: cores.inkMuted,
                            icone: Icons.label_outline_rounded,
                          ),
                        // passou do previsto: atenção, em warning
                        if (atraso > 0)
                          SeloDeStatus(
                            texto: '+${formatarDuracao(atraso)}',
                            cor: cores.warning,
                            icone: Icons.timer_outlined,
                          ),
                        // status: a cor vai no ícone e no texto
                        if (a.pago)
                          Chip(
                            avatar: Icon(
                              Icons.check_circle_outline_rounded,
                              size: 16,
                              color: cores.success,
                            ),
                            label: const Text('Pago'),
                            labelStyle: textos.labelLarge?.copyWith(
                              color: cores.success,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (a.faltou)
                          Chip(
                            avatar: Icon(
                              Icons.person_off_rounded,
                              size: 16,
                              color: cores.danger,
                            ),
                            label: const Text('Faltou'),
                            labelStyle: textos.labelLarge?.copyWith(
                              color: cores.danger,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // acabou de remarcar: a tela oferece avisar o cliente (só com
              // telefone no cadastro; sem ele, só confirma a nova data)
              if (provider.remarcado)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BrandSpacing.space4,
                    0,
                    BrandSpacing.space4,
                    BrandSpacing.space2,
                  ),
                  child: Painel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remarcado para ${_quando(a)}.',
                          style: textos.titleSmall,
                        ),
                        const SizedBox(height: BrandSpacing.space1),
                        Text(
                          a.ehAvulso
                              ? 'Atendimento avulso: não há cliente para '
                                    'avisar daqui.'
                              : telefone.isEmpty
                              ? 'O cliente não tem telefone no cadastro para '
                                    'avisar daqui.'
                              : 'Avise ${a.clienteNome} da nova data.',
                          style: textos.bodyMedium?.copyWith(
                            color: cores.inkMuted,
                          ),
                        ),
                        const SizedBox(height: BrandSpacing.space3),
                        Row(
                          children: [
                            if (telefone.isNotEmpty) ...[
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: provider.isLoading
                                      ? null
                                      : () => _avisarPeloWhatsApp(a),
                                  icon: const Icon(
                                    Icons.chat_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Avisar pelo WhatsApp'),
                                ),
                              ),
                              const SizedBox(width: BrandSpacing.space2),
                            ],
                            TextButton(
                              onPressed: provider.avisoOferecido,
                              child: Text(
                                telefone.isEmpty ? 'Ok' : 'Agora não',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // passou do previsto: quem marcou depois pode atrasar. o
              // sistema mostra; quem fala com o cliente é o dono
              if (atraso > 0 && afetados.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BrandSpacing.space4,
                    0,
                    BrandSpacing.space4,
                    BrandSpacing.space2,
                  ),
                  child: Painel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quem vem depois', style: textos.titleSmall),
                        const SizedBox(height: BrandSpacing.space1),
                        Text(
                          'Este atendimento passou ${formatarDuracao(atraso)} '
                          'do previsto. Quem marcou depois pode atrasar.',
                          style: textos.bodyMedium?.copyWith(
                            color: cores.inkMuted,
                          ),
                        ),
                        const SizedBox(height: BrandSpacing.space1),
                        for (final o in afetados)
                          _Afetado(
                            atendimento: o,
                            onAvisar: provider.textoDoAtraso(o) == null
                                ? null
                                : () => _avisarAfetado(o),
                          ),
                      ],
                    ),
                  ),
                ),

              if (provider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BrandSpacing.space4,
                    0,
                    BrandSpacing.space4,
                    BrandSpacing.space2,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(BrandSpacing.space3),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BrandRadius.mdAll,
                    ),
                    child: Text(
                      provider.errorMessage!,
                      style: textos.bodyMedium?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                ),

              const Divider(),
              // o avulso não tem cliente nem cadastro para corrigir
              if (objeto != null) ...[
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(a.clienteNome),
                  subtitle: telefone.isEmpty ? null : Text(telefone),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/clientes/${objeto.clienteId}'),
                ),
                // na chegada o dono confere o cadastro: o porte errado
                // ("veio uma caminhonete, não um carro") se corrige daqui
                ListTile(
                  leading: Icon(
                    objeto.veiculo != null
                        ? Icons.directions_car_rounded
                        : Icons.pets_rounded,
                  ),
                  title: Text(objeto.titulo),
                  subtitle: objeto.detalhe.isEmpty
                      ? null
                      : Text(objeto.detalhe),
                  trailing: const Icon(Icons.mode_edit_outline_rounded),
                  onTap: () => _corrigirObjeto(objeto),
                ),
                const Divider(),
              ],
              if (a.colaboradorNome.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.badge_rounded),
                  title: Text(a.colaboradorNome),
                  subtitle: const Text('Profissional'),
                ),
              // a duração prevista é do pátio: o serviço mais o tempo a mais
              ListTile(
                leading: const Icon(Icons.design_services_rounded),
                title: Text(a.servicoNome),
                subtitle: _duracaoPrevista(a) == null
                    ? null
                    : Text(_duracaoPrevista(a)!),
                trailing: Text(formatarDinheiro(a.servicoPreco)),
              ),
              if (a.prontoEm != null)
                ListTile(
                  leading: Icon(
                    Icons.check_circle_outline_rounded,
                    color: cores.success,
                  ),
                  title: Text('Pronto às ${formatarHora(horaDe(a.prontoEm!))}'),
                ),
              // o que foi acertado com o cliente na cobrança
              if (a.acrescimo > Decimal.fromInt(0))
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: Text(
                    a.acrescimoMotivo.isEmpty
                        ? 'Acréscimo'
                        : 'Acréscimo (${a.acrescimoMotivo})',
                  ),
                  trailing: Text('+ ${formatarDinheiro(a.acrescimo)}'),
                ),
              if (a.desconto > Decimal.fromInt(0))
                ListTile(
                  leading: const Icon(Icons.discount_rounded),
                  title: const Text('Desconto'),
                  trailing: Text('- ${formatarDinheiro(a.desconto)}'),
                ),
              ListTile(
                title: Text('Total', style: textos.titleMedium),
                trailing: Text(
                  formatarDinheiro(a.valorTotal),
                  style: textos.titleMedium,
                ),
              ),
              if (a.pagamentos.isNotEmpty) ...[
                const Divider(),
                for (final p in a.pagamentos)
                  ListTile(
                    leading: const Icon(Icons.payments_rounded),
                    title: Text(p.forma.nome),
                    subtitle: const Text('Pago'),
                    trailing: Text(formatarDinheiro(p.valor)),
                  ),
              ],
              if (a.observacao.isNotEmpty) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.notes_rounded),
                  title: const Text('Observação'),
                  subtitle: Text(a.observacao),
                ),
              ],

              const SizedBox(height: BrandSpacing.space4),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: BrandSpacing.space5,
                ),
                child: _acoes(a, provider),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _acoes(AtendimentoKanban a, AtendimentoKanbanProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final ocupado = provider.isLoading;
    final outras = provider.etapas.where((e) => e.id != a.etapaId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (outras.isNotEmpty) ...[
          Text('Mover para', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: BrandSpacing.space2),
          Wrap(
            spacing: BrandSpacing.space2,
            runSpacing: BrandSpacing.space2,
            children: [
              for (final e in outras)
                ActionChip(
                  avatar: CircleAvatar(
                    backgroundColor: corDaEtapa(e.cor, colors),
                    radius: 6,
                  ),
                  label: Text(e.nome),
                  onPressed: ocupado ? null : () => provider.mover(e.id),
                ),
            ],
          ),
          const SizedBox(height: BrandSpacing.space5),
        ],
        // o colaborador comum só cobra com a flag ligada (a API recusa com
        // sem_permissao_cobrar)
        if (ref.read(negocioAtualProvider).podeCobrar) ...[
          if (!a.pago)
            FilledButton.icon(
              onPressed: ocupado ? null : () => _cobrar(a),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.point_of_sale_rounded),
              label: const Text('Cobrar'),
            )
          else
            OutlinedButton.icon(
              onPressed: ocupado ? null : _desfazerCobranca,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Desfazer cobrança'),
            ),
          const SizedBox(height: BrandSpacing.space3),
        ],
        // o tempo a mais acaba quando o card fica pronto; remarcar muda o
        // compromisso, e o pago já aconteceu
        if (!a.pronto || !a.pago) ...[
          Row(
            children: [
              if (!a.pronto)
                Expanded(
                  child: TextButton.icon(
                    onPressed: ocupado ? null : () => _ajustarTempo(a),
                    icon: const Icon(Icons.more_time_rounded),
                    label: const Text('Ajustar tempo'),
                  ),
                ),
              if (!a.pago)
                Expanded(
                  child: TextButton.icon(
                    onPressed: ocupado ? null : () => _remarcar(a),
                    icon: const Icon(Icons.event_repeat_rounded),
                    label: const Text('Remarcar'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: BrandSpacing.space2),
        ],
        Row(
          children: [
            Expanded(
              child: a.faltou
                  ? TextButton.icon(
                      onPressed: ocupado
                          ? null
                          : () => provider.alterarFalta(false),
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Desfazer falta'),
                    )
                  : TextButton.icon(
                      // a API recusa falta em atendimento pago (falta_em_pago)
                      onPressed: ocupado || a.pago
                          ? null
                          : () => _marcarFalta(a),
                      icon: const Icon(Icons.person_off_rounded),
                      label: const Text('Faltou'),
                    ),
            ),
            if (!a.pago)
              Expanded(
                child: TextButton.icon(
                  onPressed: ocupado ? null : () => _excluir(a),
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Excluir'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// uma linha de quem vem depois do card atrasado: a hora de entrada, o nome
// (ou a identificação) com o serviço e, com telefone, o WhatsApp
class _Afetado extends StatelessWidget {
  const _Afetado({required this.atendimento, required this.onAvisar});

  final AtendimentoKanban atendimento;

  // null sem telefone: não há como avisar daqui
  final VoidCallback? onAvisar;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final o = atendimento;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Text(formatarHora(o.horarioEntrada!), style: textos.titleSmall),
      title: Text(
        '${o.rotulo} · ${o.servicoNome}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: onAvisar == null
          ? null
          : IconButton(
              tooltip: 'Avisar pelo WhatsApp',
              icon: Icon(Icons.chat_rounded, color: colors.primary),
              onPressed: onAvisar,
            ),
    );
  }
}
