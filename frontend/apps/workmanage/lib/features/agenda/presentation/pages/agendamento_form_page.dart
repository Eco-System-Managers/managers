import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/campo_data.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:managers/features/clientes/presentation/widgets/cliente_picker_sheet.dart';
import 'package:managers/features/servicos/presentation/widgets/escolher_servicos_sheet.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';

import '../../agenda_provider.dart';
import '../providers/agendamento_form_provider.dart';
import '../widgets/slots_grade.dart';

// marca um horário: cliente, serviços, profissional, dia e um slot da grade.
// fecha com true quando marcou, para a agenda recarregar
class AgendamentoFormPage extends ConsumerStatefulWidget {
  const AgendamentoFormPage({
    super.key,
    this.dataInicial,
    this.horaInicial,
    this.colaboradorId,
  });

  // o dia aberto na agenda
  final DateTime? dataInicial;

  // a hora e o profissional tocados na grade da agenda
  final Hora? horaInicial;
  final int? colaboradorId;

  NovoAgendamentoArgs get args => NovoAgendamentoArgs(
    data: dataInicial,
    hora: horaInicial,
    colaboradorId: colaboradorId,
  );

  @override
  ConsumerState<AgendamentoFormPage> createState() =>
      _AgendamentoFormPageState();
}

class _AgendamentoFormPageState extends ConsumerState<AgendamentoFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _clienteController = TextEditingController();
  final _observacoesController = TextEditingController();

  // a hora não é um campo de formulário: o erro dela é mostrado à mão
  String? _erroHora;

  AgendamentoFormProvider get _provider =>
      ref.read(agendamentoFormProvider(widget.args));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  @override
  void dispose() {
    _clienteController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _escolherCliente() async {
    final cliente = await ClientePickerSheet.abrir(
      context,
      buscar: _provider.buscarClientes,
    );
    if (cliente == null || !mounted) return;
    _clienteController.text = cliente.nome;
    _provider.selecionarCliente(cliente);
  }

  // os serviços são escolhidos numa folha; o campo mostra os nomes e o total.
  // a lista é a do profissional escolhido, quando há um
  Future<void> _escolherServicos() async {
    final escolha = await EscolherServicosSheet.abrir(
      context,
      titulo: 'Serviços',
      descricao:
          'O profissional faz um depois do outro: o tempo e o valor '
          'são a soma deles.',
      servicos: _provider.servicos,
      marcados: {for (final s in _provider.escolhidos) s.id},
    );
    if (escolha == null || !mounted) return;
    _provider.selecionarServicos(escolha);
  }

  // "09:00 – 09:50" com os serviços escolhidos (a soma das durações); só o
  // início sem eles
  String _resumoDoHorario(AgendamentoFormProvider provider) {
    final hora = provider.hora;
    if (hora == null) return '';
    final fim = provider.horaFim;
    if (fim == null) return formatarHora(hora);
    return '${formatarHora(hora)} – ${formatarHora(fim)}';
  }

  Future<void> _salvar() async {
    final formOk = _formKey.currentState!.validate();
    final horaOk = _provider.hora != null;
    setState(() => _erroHora = horaOk ? null : 'Escolha o horário');
    if (!formOk || !horaOk) return;

    await _provider.salvar(observacoes: _observacoesController.text.trim());
    // fecha aqui, uma vez, e não no build: o build roda de novo enquanto a
    // tela sai, e cada pop a mais fechava a tela de baixo
    if (mounted && _provider.salvo) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(agendamentoFormProvider(widget.args));

    return Scaffold(
      appBar: AppBar(title: const Text('Novo agendamento')),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          if (!provider.carregado) {
            final erro = provider.erroAoCarregar;
            if (erro != null) {
              return EstadoErro(
                mensagem: erro.message,
                onTentarDeNovo: provider.carregar,
              );
            }
            return const Carregando();
          }

          return _formulario(context, provider);
        },
      ),
    );
  }

  Widget _formulario(BuildContext context, AgendamentoFormProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final hoje = somenteData(DateTime.now());
    final colaboradores = provider.colaboradores;
    final idsDosServicos = provider.escolhidos.map((s) => s.id).join('-');
    final erroHora = provider.erroDoCampo('data_hora') ?? _erroHora;

    return Form(
      key: _formKey,
      child: ListView(
        padding: paddingDaPagina(context),
        children: [
          if (provider.errorMessage != null) ...[
            Container(
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
            const SizedBox(height: BrandSpacing.space4),
          ],

          if (provider.servicos.isEmpty) ...[
            _Aviso(
              texto:
                  'Cadastre um serviço ativo em Mais › Serviços para marcar '
                  'horários.',
            ),
            const SizedBox(height: BrandSpacing.space4),
          ],

          // o cliente é escolhido numa folha; o campo só mostra o nome
          TextFormField(
            controller: _clienteController,
            readOnly: true,
            onTap: _escolherCliente,
            validator: (_) =>
                provider.cliente == null ? 'Escolha o cliente' : null,
            forceErrorText: provider.erroDoCampo('cliente'),
            decoration: const InputDecoration(
              labelText: 'Cliente',
              prefixIcon: Icon(Icons.person_outline_rounded),
              suffixIcon: Icon(Icons.chevron_right_rounded),
            ),
          ),

          const SizedBox(height: BrandSpacing.space4),

          TextFormField(
            // a key nova recria o campo quando o provider troca a escolha
            // (o profissional novo pode tirar um serviço que ele não faz)
            key: ValueKey('servicos-$idsDosServicos'),
            initialValue: provider.escolhidos.map((s) => s.nome).join(', '),
            readOnly: true,
            maxLines: null,
            onTap: _escolherServicos,
            validator: (_) => provider.escolhidos.isEmpty
                ? 'Escolha ao menos um serviço'
                : null,
            forceErrorText: provider.erroDoCampo('servico_ids'),
            decoration: InputDecoration(
              labelText: 'Serviços',
              prefixIcon: const Icon(Icons.design_services_rounded),
              suffixIcon: const Icon(Icons.chevron_right_rounded),
              helperText: provider.escolhidos.isEmpty
                  ? null
                  : '${formatarDuracao(provider.duracaoTotal)} · '
                        '${formatarDinheiro(provider.valorTotal)}',
            ),
          ),

          const SizedBox(height: BrandSpacing.space4),

          DropdownButtonFormField<Colaborador>(
            key: ValueKey(
              'colaborador-$idsDosServicos-${provider.colaborador?.id}',
            ),
            initialValue: provider.colaborador,
            isExpanded: true,
            items: [
              for (final c in colaboradores)
                DropdownMenuItem(
                  value: c,
                  child: Text(
                    c.funcao.isEmpty ? c.nome : '${c.nome} · ${c.funcao}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: provider.selecionarColaborador,
            validator: (c) => c == null ? 'Escolha o profissional' : null,
            decoration: InputDecoration(
              labelText: 'Profissional',
              prefixIcon: const Icon(Icons.badge_rounded),
              helperText: colaboradores.isEmpty
                  ? provider.escolhidos.length > 1
                        ? 'Ninguém ativo faz todos esses serviços. Escolha '
                              'quem executa em Mais › Serviços.'
                        : 'Ninguém ativo executa este serviço. Escolha quem '
                              'executa em Mais › Serviços.'
                  : null,
              helperMaxLines: 2,
              errorText: provider.erroDoCampo('colaborador'),
            ),
          ),

          const SizedBox(height: BrandSpacing.space4),

          // o dia e, ao lado, o resumo do horário escolhido (início e fim).
          // o horário só se escolhe na grade de baixo
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CampoData(
                  valor: provider.data,
                  onChanged: (d) {
                    if (d != null) provider.selecionarData(d);
                  },
                  label: 'Dia',
                  limpavel: false,
                  primeiraData: hoje,
                  ultimaData: DateTime(hoje.year + 1, hoje.month, hoje.day),
                ),
              ),
              const SizedBox(width: BrandSpacing.space3),
              Expanded(
                child: InputDecorator(
                  isEmpty: provider.hora == null,
                  decoration: InputDecoration(
                    labelText: 'Horário',
                    prefixIcon: const Icon(Icons.schedule_rounded),
                    errorText: erroHora,
                  ),
                  child: Text(
                    _resumoDoHorario(provider),
                    style: textos.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: BrandSpacing.space5),

          Text('Horários livres', style: textos.titleSmall),
          const SizedBox(height: BrandSpacing.space2),
          if (provider.horaQueSaiu != null) ...[
            Text(
              'O horário das ${formatarHora(provider.horaQueSaiu!)} não está '
              'livre com os serviços e o profissional escolhidos. Escolha '
              'outro.',
              style: textos.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: BrandSpacing.space2),
          ],
          if (!provider.prontoParaGrade)
            Text(
              'Escolha os serviços e o profissional para ver os horários '
              'livres.',
              style: textos.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            )
          else
            SlotsGrade(
              slots: provider.slots,
              selecionada: provider.hora,
              carregando: provider.carregandoSlots,
              erro: provider.slotsErrorMessage,
              onTentarDeNovo: provider.recarregarGrade,
              onSelecionar: (h) {
                setState(() => _erroHora = null);
                provider.selecionarHora(h);
              },
            ),

          const SizedBox(height: BrandSpacing.space5),

          TextFormField(
            controller: _observacoesController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            forceErrorText: provider.erroDoCampo('observacoes'),
            decoration: const InputDecoration(
              labelText: 'Observações (opcional)',
            ),
          ),

          const SizedBox(height: BrandSpacing.space5),

          FilledButton(
            onPressed: provider.isLoading ? null : _salvar,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Agendar'),
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(BrandSpacing.space3),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BrandRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colors.onSecondaryContainer),
          const SizedBox(width: BrandSpacing.space3),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
