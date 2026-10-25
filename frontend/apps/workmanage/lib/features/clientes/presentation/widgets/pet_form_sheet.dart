import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/widgets/campo_data.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:validatorless/validatorless.dart';

import '../../clientes_provider.dart';
import '../../domain/entities/objeto_cliente.dart';

// cria ou edita um pet do cliente, numa folha. devolve true quando salvou
// ou removeu, para quem abriu recarregar
class PetFormSheet extends ConsumerStatefulWidget {
  const PetFormSheet({super.key, required this.clienteId, this.pet});

  final int clienteId;

  // null = novo
  final Pet? pet;

  static Future<bool> abrir(
    BuildContext context, {
    required int clienteId,
    Pet? pet,
  }) async {
    final mudou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PetFormSheet(clienteId: clienteId, pet: pet),
    );
    return mudou ?? false;
  }

  @override
  ConsumerState<PetFormSheet> createState() => _PetFormSheetState();
}

class _PetFormSheetState extends ConsumerState<PetFormSheet> {
  static final _notBlank = RegExp(r'\S');

  final _formKey = GlobalKey<FormState>();
  late final _nomeController = TextEditingController(
    text: widget.pet?.nome ?? '',
  );
  late final _especieController = TextEditingController(
    text: widget.pet?.especie ?? '',
  );
  late final _racaController = TextEditingController(
    text: widget.pet?.raca ?? '',
  );
  late PortePet? _porte = widget.pet?.porte;
  late DateTime? _nascimento = widget.pet?.dataNascimento;

  @override
  void dispose() {
    _nomeController.dispose();
    _especieController.dispose();
    _racaController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(objetoFormProvider)
        .salvarPet(
          Pet(
            id: widget.pet?.id ?? 0,
            clienteId: widget.clienteId,
            nome: _nomeController.text.trim(),
            especie: _especieController.text.trim(),
            raca: _racaController.text.trim(),
            porte: _porte,
            dataNascimento: _nascimento,
          ),
        );
  }

  Future<void> _remover() async {
    final pet = widget.pet!;
    final ok = await confirmar(
      context,
      titulo: 'Remover pet',
      mensagem:
          '${pet.nome} sai da ficha. Atendimentos já registrados '
          'continuam.',
      textoConfirmar: 'Remover',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    await ref.read(objetoFormProvider).removerPet(pet.id);
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

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                Text(
                  widget.pet == null ? 'Novo pet' : 'Editar pet',
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
                  controller: _nomeController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: Validatorless.regex(_notBlank, 'Informe o nome'),
                  forceErrorText: provider.erroDoCampo('nome'),
                  onChanged: (_) => provider.limparErroDoCampo('nome'),
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _especieController,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        forceErrorText: provider.erroDoCampo('especie'),
                        onChanged: (_) => provider.limparErroDoCampo('especie'),
                        decoration: const InputDecoration(
                          labelText: 'Espécie',
                          hintText: 'Cachorro, gato...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _racaController,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        forceErrorText: provider.erroDoCampo('raca'),
                        onChanged: (_) => provider.limparErroDoCampo('raca'),
                        decoration: const InputDecoration(
                          labelText: 'Raça',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<PortePet?>(
                  initialValue: _porte,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Não informado'),
                    ),
                    for (final p in PortePet.values)
                      DropdownMenuItem(value: p, child: Text(p.nome)),
                  ],
                  onChanged: (p) {
                    setState(() => _porte = p);
                    provider.limparErroDoCampo('porte');
                  },
                  decoration: InputDecoration(
                    labelText: 'Porte',
                    errorText: provider.erroDoCampo('porte'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                CampoData(
                  valor: _nascimento,
                  onChanged: (d) {
                    setState(() => _nascimento = d);
                    provider.limparErroDoCampo('data_nascimento');
                  },
                  label: 'Nascimento (opcional)',
                  forceErrorText: provider.erroDoCampo('data_nascimento'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: provider.isLoading ? null : _salvar,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Salvar'),
                ),
                if (widget.pet != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: provider.isLoading ? null : _remover,
                    style: TextButton.styleFrom(foregroundColor: colors.error),
                    child: const Text('Remover pet'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
