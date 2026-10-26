import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/estado_vazio.dart';

import '../../contratos_provider.dart';
import '../../domain/entities/contrato.dart';
import '../../domain/entities/modelo_contrato.dart';
import '../providers/contratos_provider.dart';
import '../providers/modelos_provider.dart';
import '../widgets/status_contrato_chip.dart';

// Mais › Contratos: os contratos gerados (filtrados por status) e, no
// segundo segmento, os modelos. gerar e os formulários abrem por cima; ao
// voltar, a lista é recarregada da API
class ContratosPage extends ConsumerStatefulWidget {
  const ContratosPage({super.key});

  @override
  ConsumerState<ContratosPage> createState() => _ContratosPageState();
}

class _ContratosPageState extends ConsumerState<ContratosPage> {
  // 0: contratos, 1: modelos
  int _segmento = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(contratosProvider).carregar();
      ref.read(modelosProvider).carregar();
    });
  }

  // a ficha pode ter mudado o status ou removido: a lista vem de novo
  Future<void> _abrirContrato(int id) async {
    await context.push('/mais/contratos/$id');
    if (mounted) ref.read(contratosProvider).carregar();
  }

  // a geração devolve o id do contrato criado: abre a ficha dele em seguida
  Future<void> _gerar() async {
    final id = await context.push<int>('/mais/contratos/gerar');
    if (!mounted) return;
    ref.read(contratosProvider).carregar();
    if (id != null) await _abrirContrato(id);
  }

  // o formulário fecha com true quando salvou ou inativou
  Future<void> _abrirModelo(String rota) async {
    final mudou = await context.push<bool>(rota);
    if (mudou == true && mounted) ref.read(modelosProvider).carregar();
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém os providers vivos enquanto a tela estiver aberta
    final contratos = ref.watch(contratosProvider);
    final modelos = ref.watch(modelosProvider);

    return ListenableBuilder(
      listenable: Listenable.merge([contratos, modelos]),
      builder: (context, _) {
        final noContratos = _segmento == 0;
        return Scaffold(
          appBar: AppBar(title: const Text('Contratos')),
          floatingActionButton: noContratos
              ? FloatingActionButton.extended(
                  onPressed: _gerar,
                  icon: const Icon(Icons.add),
                  label: const Text('Gerar contrato'),
                )
              : modelos.ehProprietario
              ? FloatingActionButton.extended(
                  onPressed: () => _abrirModelo('/mais/contratos/modelos/novo'),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo modelo'),
                )
              : null,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.description_outlined),
                      label: Text('Contratos'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.article_outlined),
                      label: Text('Modelos'),
                    ),
                  ],
                  selected: {_segmento},
                  onSelectionChanged: (s) =>
                      setState(() => _segmento = s.first),
                ),
              ),
              Expanded(
                child: noContratos
                    ? _ContratosView(
                        provider: contratos,
                        onAbrir: _abrirContrato,
                        onGerar: _gerar,
                      )
                    : _ModelosView(provider: modelos, onAbrir: _abrirModelo),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContratosView extends StatelessWidget {
  const _ContratosView({
    required this.provider,
    required this.onAbrir,
    required this.onGerar,
  });

  final ContratosProvider provider;
  final ValueChanged<int> onAbrir;
  final VoidCallback onGerar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final (status, rotulo) in [
                (null, 'Todos'),
                for (final s in StatusContrato.values) (s, s.nome),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(rotulo),
                    selected: provider.status == status,
                    onSelected: (_) => provider.filtrar(status),
                  ),
                ),
            ],
          ),
        ),
        if (provider.isLoading && provider.carregado)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        Expanded(child: _corpo(context)),
      ],
    );
  }

  Widget _corpo(BuildContext context) {
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

    if (provider.contratos.isEmpty) {
      final filtrando = provider.status != null;
      return EstadoVazio(
        icone: Icons.description_outlined,
        titulo: filtrando ? 'Nenhum contrato aqui' : 'Nenhum contrato ainda',
        mensagem: filtrando
            ? 'Nenhum contrato com este status.'
            : 'Gere um contrato a partir de um modelo e mande o PDF '
                  'para o cliente.',
        acao: filtrando
            ? null
            : FilledButton.icon(
                onPressed: onGerar,
                icon: const Icon(Icons.add),
                label: const Text('Gerar contrato'),
              ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.carregar,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: provider.contratos.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final c = provider.contratos[index];
          return ListTile(
            title: Text(c.titulo),
            subtitle: Text('${c.clienteNome} · ${formatarData(c.criadoEm)}'),
            trailing: StatusContratoChip(status: c.status),
            onTap: () => onAbrir(c.id),
          );
        },
      ),
    );
  }
}

class _ModelosView extends StatelessWidget {
  const _ModelosView({required this.provider, required this.onAbrir});

  final ModelosProvider provider;
  final ValueChanged<String> onAbrir;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        SwitchListTile(
          title: const Text('Mostrar inativos'),
          value: provider.mostrarInativos,
          onChanged: provider.isLoading ? null : provider.alternarInativos,
        ),
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              provider.errorMessage!,
              style: TextStyle(color: colors.error),
            ),
          ),
        Expanded(child: _corpo(context)),
      ],
    );
  }

  Widget _corpo(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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

    if (provider.modelos.isEmpty) {
      return EstadoVazio(
        icone: Icons.article_outlined,
        titulo: 'Nenhum modelo ainda',
        mensagem: provider.ehProprietario
            ? 'O modelo é o texto do contrato, com as variáveis que viram '
                  'os dados do cliente ao gerar.'
            : 'Peça ao proprietário para cadastrar os modelos.',
        acao: provider.ehProprietario
            ? FilledButton.icon(
                onPressed: () => onAbrir('/mais/contratos/modelos/novo'),
                icon: const Icon(Icons.add),
                label: const Text('Criar modelo'),
              )
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: provider.carregar,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: provider.modelos.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final ModeloContrato m = provider.modelos[index];
          final podeEditar = provider.ehProprietario;
          return ListTile(
            onTap: podeEditar
                ? () => onAbrir('/mais/contratos/modelos/${m.id}')
                : null,
            title: Text(
              m.titulo,
              style: m.ativo
                  ? null
                  : TextStyle(
                      color: colors.outline,
                      decoration: TextDecoration.lineThrough,
                    ),
            ),
            subtitle: Text(
              m.corpo.replaceAll('\n', ' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: m.ativo
                ? (podeEditar ? const Icon(Icons.chevron_right) : null)
                : Chip(
                    label: const Text('Inativo'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
          );
        },
      ),
    );
  }
}
