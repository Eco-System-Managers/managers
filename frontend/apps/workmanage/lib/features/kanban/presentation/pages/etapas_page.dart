import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:validatorless/validatorless.dart';

import '../../domain/entities/etapa.dart';
import '../../kanban_provider.dart';
import '../widgets/cor_da_etapa.dart';

// as colunas do quadro, para o proprietário: renomear, trocar a cor,
// arrastar para reordenar, criar e remover. a ordem define o status que o
// cliente vê no app dele (primeira = aguardando, última = concluído)
class EtapasPage extends ConsumerStatefulWidget {
  const EtapasPage({super.key});

  @override
  ConsumerState<EtapasPage> createState() => _EtapasPageState();
}

class _EtapasPageState extends ConsumerState<EtapasPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(etapasProvider).carregar();
    });
  }

  Future<void> _editar([Etapa? etapa]) async {
    await abrirFolha<void>(
      context,
      builder: (_) => _EtapaFormSheet(etapa: etapa),
    );
  }

  Future<void> _remover(Etapa etapa) async {
    final ok = await confirmar(
      context,
      titulo: 'Remover etapa',
      mensagem:
          'A coluna "${etapa.nome}" sai do quadro. Só dá para remover '
          'uma etapa sem atendimentos.',
      textoConfirmar: 'Remover',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    await ref.read(etapasProvider).remover(etapa.id);
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(etapasProvider);
    final colors = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Etapas do quadro')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: provider.carregado ? () => _editar() : null,
            icon: const Icon(Icons.add),
            label: const Text('Nova etapa'),
          ),
          body: !provider.carregado
              ? (provider.erroAoCarregar != null
                    ? EstadoErro(
                        mensagem: provider.erroAoCarregar!.message,
                        onTentarDeNovo: provider.carregar,
                      )
                    : const Carregando())
              : Column(
                  children: [
                    if (provider.isLoading)
                      const LinearProgressIndicator(minHeight: 2)
                    else
                      const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        'Arraste para mudar a ordem. A primeira coluna é onde '
                        'o atendimento entra; a última é a de concluído.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                    if (provider.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Text(
                          provider.errorMessage!,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: provider.etapas.length,
                        // onReorderItem já desconta o item removido do índice de destino
                        onReorderItem: (de, para) {
                          if (para != de) provider.reordenar(de, para);
                        },
                        itemBuilder: (context, index) {
                          final etapa = provider.etapas[index];
                          return ListTile(
                            key: ValueKey(etapa.id),
                            leading: CircleAvatar(
                              radius: 10,
                              backgroundColor: corDaEtapa(etapa.cor, colors),
                            ),
                            title: Text(etapa.nome),
                            subtitle: Text(
                              index == 0
                                  ? 'Entrada (aguardando)'
                                  : index == provider.etapas.length - 1
                                  ? 'Saída (concluído)'
                                  : 'Em atendimento',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Editar',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editar(etapa),
                                ),
                                IconButton(
                                  tooltip: 'Remover',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _remover(etapa),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.drag_handle),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// nome e cor de uma etapa, nova ou existente
class _EtapaFormSheet extends ConsumerStatefulWidget {
  const _EtapaFormSheet({this.etapa});

  final Etapa? etapa;

  @override
  ConsumerState<_EtapaFormSheet> createState() => _EtapaFormSheetState();
}

class _EtapaFormSheetState extends ConsumerState<_EtapaFormSheet> {
  static final _notBlank = RegExp(r'\S');

  final _formKey = GlobalKey<FormState>();
  late final _nomeController = TextEditingController(
    text: widget.etapa?.nome ?? '',
  );
  late String _cor = widget.etapa?.cor.isNotEmpty == true
      ? widget.etapa!.cor
      : coresDeEtapa.first;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final base = widget.etapa ?? const Etapa(nome: '');
    await ref
        .read(etapasProvider)
        .salvar(base.copyWith(nome: _nomeController.text.trim(), cor: _cor));
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(etapasProvider);
    final colors = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        if (provider.salvo) {
          provider.avisoDeSalvoMostrado();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).pop();
          });
        }

        return Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              Text(
                widget.etapa == null ? 'Nova etapa' : 'Editar etapa',
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
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                validator: Validatorless.regex(_notBlank, 'Informe o nome'),
                forceErrorText: provider.erroDoCampo('nome'),
                onChanged: (_) => provider.limparErroDoCampo('nome'),
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Ex.: Lavando',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Cor', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final hex in coresDeEtapa)
                    InkWell(
                      onTap: () => setState(() => _cor = hex),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: corDaEtapa(hex, colors),
                          border: Border.all(
                            color: _cor == hex
                                ? colors.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: _cor == hex
                            ? const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              if (provider.erroDoCampo('cor') != null) ...[
                const SizedBox(height: 8),
                Text(
                  provider.erroDoCampo('cor')!,
                  style: TextStyle(color: colors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: provider.isLoading ? null : _salvar,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Salvar'),
              ),
            ],
          ),
        );
      },
    );
  }
}
