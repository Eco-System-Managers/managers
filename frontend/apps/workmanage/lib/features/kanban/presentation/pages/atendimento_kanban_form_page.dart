import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/campo_data.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/features/clientes/domain/entities/objeto_cliente.dart';
import 'package:managers/features/clientes/presentation/widgets/cliente_picker_sheet.dart';
import 'package:managers/features/clientes/presentation/widgets/pet_form_sheet.dart';
import 'package:managers/features/clientes/presentation/widgets/veiculo_form_sheet.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';

import '../../kanban_provider.dart';
import '../providers/atendimento_kanban_form_provider.dart';

// recebe um atendimento na esteira: cliente, o veículo ou pet dele, serviço,
// dia e uma hora de entrada opcional. fecha com true quando entrou
class AtendimentoKanbanFormPage extends ConsumerStatefulWidget {
  const AtendimentoKanbanFormPage({super.key, this.dataInicial});

  // o dia aberto no quadro
  final DateTime? dataInicial;

  @override
  ConsumerState<AtendimentoKanbanFormPage> createState() =>
      _AtendimentoKanbanFormPageState();
}

class _AtendimentoKanbanFormPageState
    extends ConsumerState<AtendimentoKanbanFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _clienteController = TextEditingController();
  final _observacaoController = TextEditingController();

  // com hora marcada ou sem
  bool _comHora = false;

  AtendimentoKanbanFormProvider get _provider =>
      ref.read(atendimentoKanbanFormProvider(widget.dataInicial));

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
    _observacaoController.dispose();
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

  Future<void> _novoObjeto() async {
    final cliente = _provider.cliente;
    if (cliente == null) return;
    final mudou = _provider.tipoObjeto == TipoObjeto.veiculo
        ? await VeiculoFormSheet.abrir(context, clienteId: cliente.id)
        : await PetFormSheet.abrir(context, clienteId: cliente.id);
    if (mudou && mounted) await _provider.recarregarCliente();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    await _provider.salvar(observacao: _observacaoController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(
      atendimentoKanbanFormProvider(widget.dataInicial),
    );
    final veiculo = provider.tipoObjeto == TipoObjeto.veiculo;

    return Scaffold(
      appBar: AppBar(title: Text(veiculo ? 'Receber veículo' : 'Receber pet')),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          if (provider.salvo) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.pop(true);
            });
          }

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

          return _formulario(context, provider, veiculo);
        },
      ),
    );
  }

  Widget _formulario(
    BuildContext context,
    AtendimentoKanbanFormProvider provider,
    bool veiculo,
  ) {
    final colors = Theme.of(context).colorScheme;
    final hoje = somenteData(DateTime.now());
    final objetos = provider.objetos;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (provider.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                provider.errorMessage!,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // o cliente é escolhido numa folha; o campo só mostra o nome
          TextFormField(
            controller: _clienteController,
            readOnly: true,
            onTap: _escolherCliente,
            validator: (_) =>
                provider.cliente == null ? 'Escolha o cliente' : null,
            decoration: const InputDecoration(
              labelText: 'Cliente',
              prefixIcon: Icon(Icons.person_outline),
              suffixIcon: Icon(Icons.chevron_right),
              border: OutlineInputBorder(),
            ),
          ),

          if (provider.cliente != null) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<ObjetoCliente>(
              // a key nova recria o campo quando o provider troca o valor
              key: ValueKey(
                'objeto-${provider.cliente?.id}-${provider.objeto?.id}',
              ),
              initialValue: provider.objeto,
              isExpanded: true,
              items: [
                for (final o in objetos)
                  DropdownMenuItem(
                    value: o,
                    child: Text(
                      o.detalhe.isEmpty
                          ? o.titulo
                          : '${o.titulo} · ${o.detalhe}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: provider.selecionarObjeto,
              validator: (o) => o == null
                  ? (veiculo ? 'Escolha o veículo' : 'Escolha o pet')
                  : null,
              decoration: InputDecoration(
                labelText: veiculo ? 'Veículo' : 'Pet',
                prefixIcon: Icon(
                  veiculo ? Icons.directions_car_outlined : Icons.pets,
                ),
                helperText: objetos.isEmpty
                    ? (veiculo
                          ? 'Este cliente ainda não tem veículo cadastrado.'
                          : 'Este cliente ainda não tem pet cadastrado.')
                    : null,
                errorText: provider.erroDoCampo('objeto'),
                border: const OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _novoObjeto,
                icon: const Icon(Icons.add),
                label: Text(veiculo ? 'Novo veículo' : 'Novo pet'),
              ),
            ),
          ],

          const SizedBox(height: 8),

          DropdownButtonFormField<Servico>(
            key: ValueKey('servico-${provider.servico?.id}'),
            initialValue: provider.servico,
            isExpanded: true,
            items: [
              for (final s in provider.servicos)
                DropdownMenuItem(
                  value: s,
                  child: Text(
                    '${s.nome} · ${formatarDinheiro(s.preco)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: provider.selecionarServico,
            validator: (s) => s == null ? 'Escolha o serviço' : null,
            decoration: InputDecoration(
              labelText: 'Serviço',
              prefixIcon: const Icon(Icons.design_services_outlined),
              helperText: provider.servicos.isEmpty
                  ? 'Cadastre um serviço ativo na aba Serviços.'
                  : null,
              errorText: provider.erroDoCampo('servico'),
              border: const OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          CampoData(
            valor: provider.data,
            onChanged: (d) {
              if (d != null) provider.selecionarData(d);
            },
            label: 'Dia',
            limpavel: false,
            primeiraData: DateTime(hoje.year - 1, hoje.month, hoje.day),
            ultimaData: DateTime(hoje.year + 1, hoje.month, hoje.day),
            forceErrorText: provider.erroDoCampo('data'),
          ),

          const SizedBox(height: 24),

          Text(
            'Hora de entrada',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Sem hora marcada')),
              ButtonSegment(value: true, label: Text('Marcar hora')),
            ],
            selected: {_comHora},
            onSelectionChanged: (s) {
              setState(() => _comHora = s.first);
              if (!_comHora) provider.selecionarHora(null);
            },
          ),
          if (_comHora) ...[
            const SizedBox(height: 12),
            _GradeDeEntrada(provider: provider),
          ],
          if (provider.erroDoCampo('horario_entrada') != null) ...[
            const SizedBox(height: 8),
            Text(
              provider.erroDoCampo('horario_entrada')!,
              style: TextStyle(color: colors.error, fontSize: 12),
            ),
          ],

          const SizedBox(height: 24),

          TextFormField(
            controller: _observacaoController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            forceErrorText: provider.erroDoCampo('observacao'),
            decoration: const InputDecoration(
              labelText: 'Observação (opcional)',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          FilledButton(
            onPressed: provider.isLoading ? null : _salvar,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Receber'),
          ),
        ],
      ),
    );
  }
}

// as horas de entrada livres do dia, pela capacidade do expediente
class _GradeDeEntrada extends StatelessWidget {
  const _GradeDeEntrada({required this.provider});

  final AtendimentoKanbanFormProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (provider.carregandoSlots) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final erro = provider.slotsErrorMessage;
    if (erro != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(erro, style: TextStyle(color: colors.error)),
          TextButton(
            onPressed: provider.recarregarGrade,
            child: const Text('Tentar de novo'),
          ),
        ],
      );
    }
    if (provider.slots.isEmpty) {
      return Text(
        'Sem horas livres neste dia: o negócio não abre, não tem capacidade '
        'definida nos horários ou já lotou.',
        style: TextStyle(color: colors.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final hora in provider.slots)
          ChoiceChip(
            label: Text(formatarHora(hora)),
            selected: provider.hora == hora,
            onSelected: (_) => provider.selecionarHora(hora),
          ),
      ],
    );
  }
}
