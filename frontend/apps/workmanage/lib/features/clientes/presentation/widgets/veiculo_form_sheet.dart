import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:validatorless/validatorless.dart';

import '../../clientes_provider.dart';
import '../../domain/entities/objeto_cliente.dart';
import 'escolha_de_porte.dart';

// cria ou edita um veículo do cliente, numa folha. devolve true quando
// salvou ou removeu, para quem abriu recarregar
class VeiculoFormSheet extends ConsumerStatefulWidget {
  const VeiculoFormSheet({
    super.key,
    required this.clienteId,
    this.veiculo,
    this.permitirRemover = true,
  });

  final int clienteId;

  // null = novo
  final Veiculo? veiculo;

  // false quando a folha abre de um atendimento, para corrigir o cadastro:
  // ali o veículo tem atendimento e não sai da ficha
  final bool permitirRemover;

  static Future<bool> abrir(
    BuildContext context, {
    required int clienteId,
    Veiculo? veiculo,
    bool permitirRemover = true,
  }) async {
    final mudou = await abrirFolha<bool>(
      context,
      builder: (_) => VeiculoFormSheet(
        clienteId: clienteId,
        veiculo: veiculo,
        permitirRemover: permitirRemover,
      ),
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
  late Porte? _porte = widget.veiculo?.porte;

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
            porte: _porte,
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
    final textos = Theme.of(context).textTheme;

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
            padding: const EdgeInsets.fromLTRB(
              BrandSpacing.space5,
              BrandSpacing.space4,
              BrandSpacing.space5,
              BrandSpacing.space5,
            ),
            children: [
              Text(
                widget.veiculo == null ? 'Novo veículo' : 'Editar veículo',
                style: textos.titleLarge,
              ),
              const SizedBox(height: BrandSpacing.space4),
              if (provider.errorMessage != null) ...[
                Text(
                  provider.errorMessage!,
                  style: textos.bodyMedium?.copyWith(color: colors.error),
                ),
                const SizedBox(height: BrandSpacing.space3),
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
                decoration: const InputDecoration(labelText: 'Placa'),
              ),
              const SizedBox(height: BrandSpacing.space4),
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
                      decoration: const InputDecoration(labelText: 'Marca'),
                    ),
                  ),
                  const SizedBox(width: BrandSpacing.space3),
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
                      decoration: const InputDecoration(labelText: 'Modelo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BrandSpacing.space4),
              TextFormField(
                controller: _corController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _salvar(),
                validator: Validatorless.regex(_notBlank, 'Informe a cor'),
                forceErrorText: provider.erroDoCampo('cor'),
                onChanged: (_) => provider.limparErroDoCampo('cor'),
                decoration: const InputDecoration(labelText: 'Cor'),
              ),
              const SizedBox(height: BrandSpacing.space4),
              EscolhaDePorte(
                tipo: TipoObjeto.veiculo,
                valor: _porte,
                onChanged: (porte) {
                  setState(() => _porte = porte);
                  provider.limparErroDoCampo('porte');
                },
                forceErrorText: provider.erroDoCampo('porte'),
              ),
              const SizedBox(height: BrandSpacing.space5),
              FilledButton(
                onPressed: provider.isLoading ? null : _salvar,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Salvar'),
              ),
              if (widget.veiculo != null && widget.permitirRemover) ...[
                const SizedBox(height: BrandSpacing.space2),
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
