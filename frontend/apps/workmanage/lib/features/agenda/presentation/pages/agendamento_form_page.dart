import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/campo_data.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/features/clientes/presentation/widgets/cliente_picker_sheet.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';

import '../../agenda_provider.dart';
import '../providers/agendamento_form_provider.dart';
import '../widgets/slots_grade.dart';

// marca um horário: cliente, serviço, profissional, dia e um slot da grade.
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

  Future<void> _salvar() async {
    final formOk = _formKey.currentState!.validate();
    final horaOk = _provider.hora != null;
    setState(() => _erroHora = horaOk ? null : 'Escolha o horário');
    if (!formOk || !horaOk) return;

    await _provider.salvar(observacoes: _observacoesController.text.trim());
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

          return _formulario(context, provider);
        },
      ),
    );
  }

  Widget _formulario(BuildContext context, AgendamentoFormProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final hoje = somenteData(DateTime.now());
    final colaboradores = provider.colaboradores;
    final erroHora = provider.erroDoCampo('data_hora') ?? _erroHora;

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

          if (provider.servicos.isEmpty) ...[
            _Aviso(
              texto:
                  'Cadastre um serviço ativo na aba Serviços para marcar '
                  'horários.',
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
            forceErrorText: provider.erroDoCampo('cliente'),
            decoration: const InputDecoration(
              labelText: 'Cliente',
              prefixIcon: Icon(Icons.person_outline),
              suffixIcon: Icon(Icons.chevron_right),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<Servico>(
            // a key nova recria o campo quando o provider troca o valor
            key: ValueKey('servico-${provider.servico?.id}'),
            initialValue: provider.servico,
            isExpanded: true,
            items: [
              for (final s in provider.servicos)
                DropdownMenuItem(
                  value: s,
                  child: Text(
                    '${s.nome} · ${s.duracao} min · ${formatarDinheiro(s.preco)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: provider.selecionarServico,
            validator: (s) => s == null ? 'Escolha o serviço' : null,
            decoration: InputDecoration(
              labelText: 'Serviço',
              prefixIcon: const Icon(Icons.design_services_outlined),
              errorText: provider.erroDoCampo('servico_id'),
              border: const OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),

          DropdownButtonFormField<Colaborador>(
            key: ValueKey(
              'colaborador-${provider.servico?.id}-${provider.colaborador?.id}',
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
              prefixIcon: const Icon(Icons.badge_outlined),
              helperText: colaboradores.isEmpty
                  ? 'Ninguém ativo executa este serviço.'
                  : null,
              errorText: provider.erroDoCampo('colaborador'),
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
            primeiraData: hoje,
            ultimaData: DateTime(hoje.year + 1, hoje.month, hoje.day),
          ),

          const SizedBox(height: 24),

          Text('Horário', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (!provider.prontoParaGrade)
            Text(
              'Escolha o serviço e o profissional para ver os horários livres.',
              style: TextStyle(color: colors.onSurfaceVariant),
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
          if (erroHora != null) ...[
            const SizedBox(height: 8),
            Text(erroHora, style: TextStyle(color: colors.error, fontSize: 12)),
          ],

          const SizedBox(height: 24),

          TextFormField(
            controller: _observacoesController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            forceErrorText: provider.erroDoCampo('observacoes'),
            decoration: const InputDecoration(
              labelText: 'Observações (opcional)',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colors.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
