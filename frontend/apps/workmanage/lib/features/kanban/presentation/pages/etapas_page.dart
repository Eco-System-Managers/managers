import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:managers/core/widgets/selo_de_status.dart';
import 'package:validatorless/validatorless.dart';

import '../../domain/entities/etapa.dart';
import '../../kanban_provider.dart';
import '../providers/etapas_provider.dart';
import '../widgets/cor_da_etapa.dart';

// as colunas do quadro, para o proprietário: renomear, trocar a cor,
// arrastar para reordenar, criar, remover e marcar qual é a de pronto. a
// primeira é onde o atendimento entra ("aguardando" para o cliente); a de
// pronto libera a vaga e avisa o cliente, e as depois dela também contam
// como pronto
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

  // o que a etapa significa, pela posição: entrada, pronto (ou depois) ou o
  // meio do caminho
  String _papel(EtapasProvider provider, Etapa etapa, int index) {
    if (index == 0) return 'Entrada (aguardando)';
    if (provider.ehDePronto(etapa)) {
      return 'Pronto: libera a vaga e avisa o cliente';
    }
    if (provider.ehDepoisDePronto(etapa)) return 'Depois de pronto';
    return 'Em atendimento';
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(etapasProvider);
    final colors = Theme.of(context).colorScheme;
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Etapas do quadro')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: provider.carregado ? () => _editar() : null,
            icon: const Icon(Icons.add_rounded),
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
                      padding: const EdgeInsets.fromLTRB(
                        BrandSpacing.space4,
                        BrandSpacing.space3,
                        BrandSpacing.space4,
                        BrandSpacing.space1,
                      ),
                      child: Text(
                        'Arraste para mudar a ordem. A primeira coluna é onde '
                        'o atendimento entra. A etapa de pronto libera a vaga '
                        'e avisa o cliente; as que vêm depois dela também '
                        'contam como pronto.',
                        style: textos.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (provider.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          BrandSpacing.space4,
                          BrandSpacing.space1,
                          BrandSpacing.space4,
                          0,
                        ),
                        child: Text(
                          provider.errorMessage!,
                          style: textos.bodyMedium?.copyWith(
                            color: colors.error,
                          ),
                        ),
                      ),
                    Expanded(
                      child: ReorderableListView.builder(
                        // embaixo, a folga do botão flutuante
                        padding: const EdgeInsets.only(
                          bottom: BrandSpacing.space7,
                        ),
                        itemCount: provider.etapas.length,
                        // onReorderItem já desconta o item removido do índice de destino
                        onReorderItem: (de, para) {
                          if (para != de) provider.reordenar(de, para);
                        },
                        // a linha arrastada flutua sobre a lista: o azul suave
                        // de destaque com a sombra do Design System
                        proxyDecorator: (child, _, _) => DecoratedBox(
                          decoration: BoxDecoration(
                            boxShadow: BrandShadows.card(context),
                          ),
                          child: Material(
                            color: BrandColors.of(context).blueSoft,
                            child: child,
                          ),
                        ),
                        itemBuilder: (context, index) {
                          final etapa = provider.etapas[index];
                          final pronto = provider.ehDePronto(etapa);
                          return ListTile(
                            key: ValueKey(etapa.id),
                            leading: CircleAvatar(
                              radius: 10,
                              backgroundColor: corDaEtapa(etapa.cor, colors),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    etapa.nome,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // pronto é concluído: success
                                if (pronto) ...[
                                  const SizedBox(width: BrandSpacing.space2),
                                  SeloDeStatus(
                                    texto: 'Pronto',
                                    cor: cores.success,
                                    icone: Icons.check_circle_outline_rounded,
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(_papel(provider, etapa, index)),
                            onTap: () => _editar(etapa),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PopupMenuButton<_AcaoDaEtapa>(
                                  tooltip: 'Mais ações',
                                  onSelected: (acao) => switch (acao) {
                                    _AcaoDaEtapa.editar => _editar(etapa),
                                    _AcaoDaEtapa.pronto =>
                                      provider.marcarPronto(etapa.id),
                                    _AcaoDaEtapa.remover => _remover(etapa),
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: _AcaoDaEtapa.editar,
                                      child: Text('Editar'),
                                    ),
                                    if (!pronto)
                                      const PopupMenuItem(
                                        value: _AcaoDaEtapa.pronto,
                                        child: Text('Marcar como pronto'),
                                      ),
                                    const PopupMenuItem(
                                      value: _AcaoDaEtapa.remover,
                                      child: Text('Remover'),
                                    ),
                                  ],
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.all(
                                      BrandSpacing.space2,
                                    ),
                                    child: Icon(Icons.drag_handle_rounded),
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

// o menu de uma etapa: editar, marcar como pronto e remover
enum _AcaoDaEtapa { editar, pronto, remover }

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

  // a amostra é a mesma nos dois temas: o check é marinho sobre a cor clara
  // e branco sobre a escura (o ink do tema escuro sumiria na cor clara)
  Color _corDoCheck(Color amostra) {
    final cores = BrandColors.of(context);
    return ThemeData.estimateBrightnessForColor(amostra) == Brightness.light
        ? cores.navy
        : cores.onBrand;
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(etapasProvider);
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

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
            padding: const EdgeInsets.fromLTRB(
              BrandSpacing.space5,
              BrandSpacing.space4,
              BrandSpacing.space5,
              BrandSpacing.space5,
            ),
            children: [
              Text(
                widget.etapa == null ? 'Nova etapa' : 'Editar etapa',
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
                controller: _nomeController,
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                validator: Validatorless.regex(_notBlank, 'Informe o nome'),
                forceErrorText: provider.erroDoCampo('nome'),
                onChanged: (_) => provider.limparErroDoCampo('nome'),
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  hintText: 'Ex.: Lavando',
                ),
              ),
              const SizedBox(height: BrandSpacing.space4),
              Text('Cor', style: textos.titleSmall),
              const SizedBox(height: BrandSpacing.space2),
              Wrap(
                spacing: BrandSpacing.space2,
                runSpacing: BrandSpacing.space2,
                children: [
                  for (final hex in coresDeEtapa)
                    InkWell(
                      onTap: () => setState(() => _cor = hex),
                      customBorder: const CircleBorder(),
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
                            ? Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: _corDoCheck(corDaEtapa(hex, colors)),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              if (provider.erroDoCampo('cor') != null) ...[
                const SizedBox(height: BrandSpacing.space2),
                Text(
                  provider.erroDoCampo('cor')!,
                  style: textos.bodySmall?.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: BrandSpacing.space5),
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
