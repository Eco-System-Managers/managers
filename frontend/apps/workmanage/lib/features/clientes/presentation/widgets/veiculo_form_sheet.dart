import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:validatorless/validatorless.dart';

import '../../clientes_provider.dart';
import '../../domain/entities/objeto_cliente.dart';

// cria ou edita um veículo do cliente, numa folha. devolve true quando
// salvou ou removeu, para quem abriu recarregar
class VeiculoFormSheet extends ConsumerStatefulWidget {
  const VeiculoFormSheet({super.key, required this.clienteId, this.veiculo});

  final int clienteId;

  // null = novo
  final Veiculo? veiculo;

  static Future<bool> abrir(
    BuildContext context, {
    required int clienteId,
    Veiculo? veiculo,
  }) async {
    final mudou = await abrirFolha<bool>(
      context,
      builder: (_) => VeiculoFormSheet(clienteId: clienteId, veiculo: veiculo),
    );
    return mudou ?? false;
  }

  @override
  ConsumerState<VeiculoFormSheet> createState() => _VeiculoFormSheetState();
}

class _VeiculoFormSheetState extends ConsumerState<VeiculoFormSheet> {
  static final _notBlank = RegExp(r'\S');

  final _formKey = GlobalKey<FormState>();
  late final _placaController = TextEditingController(
    text: widget.veiculo?.placa ?? '',
  );
  late final _marcaController = TextEditingController(
    text: widget.veiculo?.marca ?? '',
  );
  late final _modeloController = TextEditingController(
    text: widget.veiculo?.modelo ?? '',
  );
  late final _corController = TextEditingController(
    text: widget.veiculo?.cor ?? '',
  );

  @override
  void dispose() {
    _placaController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _corController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(objetoFormProvider)
        .salvarVeiculo(
          Veiculo(
            id: widget.veiculo?.id ?? 0,
            clienteId: widget.clienteId,
            placa: _placaController.text.trim().toUpperCase(),
            marca: _marcaController.text.trim(),
            modelo: _modeloController.text.trim(),
            cor: _corController.text.trim(),
          ),
        );
  }

  Future<void> _remover() async {
    final veiculo = widget.veiculo!;
    final ok = await confirmar(
      context,
      titulo: 'Remover veículo',
      mensagem:
          '${veiculo.titulo} (${veiculo.placa}) sai da ficha. '
          'Atendimentos já registrados continuam.',
      textoConfirmar: 'Remover',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    await ref.read(objetoFormProvider).removerVeiculo(veiculo.id);
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a folha estiver aberta
    final provider = ref.watch(objetoFormProvider);
    final colors = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        if (provider.salvo || provider.removido) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).pop(true);
          });
        }

        return Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              Text(
                widget.veiculo == null ? 'Novo veículo' : 'Editar veículo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (provider.errorMessage != null) ...[
                Text(
                  provider.errorMessage!,
                  style: TextStyle(color: colors.error),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _placaController,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: Validatorless.regex(_notBlank, 'Informe a placa'),
                forceErrorText: provider.erroDoCampo('placa'),
                onChanged: (_) => provider.limparErroDoCampo('placa'),
                decoration: const InputDecoration(
                  labelText: 'Placa',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _marcaController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: Validatorless.regex(
                        _notBlank,
                        'Informe a marca',
                      ),
                      forceErrorText: provider.erroDoCampo('marca'),
                      onChanged: (_) => provider.limparErroDoCampo('marca'),
                      decoration: const InputDecoration(
                        labelText: 'Marca',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _modeloController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: Validatorless.regex(
                        _notBlank,
                        'Informe o modelo',
                      ),
                      forceErrorText: provider.erroDoCampo('modelo'),
                      onChanged: (_) => provider.limparErroDoCampo('modelo'),
                      decoration: const InputDecoration(
                        labelText: 'Modelo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _corController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _salvar(),
                validator: Validatorless.regex(_notBlank, 'Informe a cor'),
                forceErrorText: provider.erroDoCampo('cor'),
                onChanged: (_) => provider.limparErroDoCampo('cor'),
                decoration: const InputDecoration(
                  labelText: 'Cor',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: provider.isLoading ? null : _salvar,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Salvar'),
              ),
              if (widget.veiculo != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: provider.isLoading ? null : _remover,
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  child: const Text('Remover veículo'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
