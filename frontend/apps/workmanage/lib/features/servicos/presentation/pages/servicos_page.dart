import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/estado_vazio.dart';
import 'package:managers/core/widgets/selo_de_status.dart';
import 'package:managers/features/clientes/domain/entities/porte.dart';
import 'package:managers/features/empresa/domain/entities/nicho.dart';
import 'package:managers/features/empresa/presentation/widgets/nicho_visual.dart';

import '../../domain/entities/servico.dart';
import '../../servicos_provider.dart';
import '../providers/servicos_provider.dart';

// o catálogo: busca, filtro de inativos e a lista. com 2 ou mais nichos a
// lista vira pastas, uma por nicho, e cada pasta cria serviço já nela.
// criar e editar abrem o formulário por cima; ao voltar, a lista é
// recarregada da API
class ServicosPage extends ConsumerStatefulWidget {
  const ServicosPage({super.key});

  @override
  ConsumerState<ServicosPage> createState() => _ServicosPageState();
}

class _ServicosPageState extends ConsumerState<ServicosPage> {
  final _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // depois do primeiro build: o watch já está segurando o provider vivo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(servicosProvider).carregar();
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  // o formulário fecha com true quando salvou ou inativou
  Future<void> _abrir(String rota) async {
    final mudou = await context.push<bool>(rota);
    if (mudou == true && mounted) ref.read(servicosProvider).carregar();
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a aba estiver aberta
    final provider = ref.watch(servicosProvider);

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Serviços')),
          floatingActionButton: provider.ehProprietario
              ? FloatingActionButton(
                  onPressed: () => _abrir('/mais/servicos/novo'),
                  tooltip: 'Novo serviço',
                  child: const Icon(Icons.add_rounded),
                )
              : null,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BrandSpacing.space4,
                  BrandSpacing.space2,
                  BrandSpacing.space4,
                  0,
                ),
                child: TextField(
                  controller: _buscaController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: provider.buscar,
                  decoration: InputDecoration(
                    hintText: 'Buscar serviço',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _buscaController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _buscaController.clear();
                              provider.buscar('');
                            },
                          ),
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Mostrar inativos'),
                value: provider.mostrarInativos,
                onChanged: provider.isLoading
                    ? null
                    : provider.alternarInativos,
              ),
              if (provider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BrandSpacing.space4,
                  ),
                  child: Text(
                    provider.errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Expanded(child: _corpo(provider)),
            ],
          ),
        );
      },
    );
  }

  Widget _corpo(ServicosProvider provider) {
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

    if (provider.servicos.isEmpty) {
      final buscando = provider.busca.isNotEmpty;
      return EstadoVazio(
        icone: Icons.design_services_rounded,
        titulo: buscando ? 'Nada encontrado' : 'Nenhum serviço ainda',
        mensagem: buscando
            ? 'Tente outro nome.'
            : 'Cadastre o que o seu negócio oferece: nome, duração e preço.',
        acao: provider.ehProprietario && !buscando
            ? FilledButton.icon(
                onPressed: () => _abrir('/mais/servicos/novo'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Cadastrar serviço'),
              )
            : null,
      );
    }

    if (provider.emPastas) return _pastas(provider);

    return RefreshIndicator(
      onRefresh: provider.carregar,
      child: ListView.separated(
        // folga para o botão flutuante não cobrir o fim da lista
        padding: const EdgeInsets.only(bottom: BrandSpacing.space7),
        itemCount: provider.servicos.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final servico = provider.servicos[index];
          return _ServicoTile(
            servico: servico,
            onTap: provider.ehProprietario
                ? () => _abrir('/mais/servicos/${servico.id}')
                : null,
          );
        },
      ),
    );
  }

  Widget _pastas(ServicosProvider provider) {
    return RefreshIndicator(
      onRefresh: provider.carregar,
      child: ListView(
        // folga para o botão flutuante não cobrir o fim da lista
        padding: const EdgeInsets.only(bottom: BrandSpacing.space7),
        children: [
          for (final pasta in provider.pastas) ...[
            _CabecalhoDaPasta(
              nicho: pasta.nicho,
              quantidade: pasta.servicos.length,
              recolhida: provider.recolhida(pasta.nicho),
              onAlternar: () => provider.alternarPasta(pasta.nicho),
              // a pasta dos nichos removidos não recebe serviço novo
              onNovo: provider.ehProprietario && pasta.nicho != null
                  ? () =>
                        _abrir('/mais/servicos/novo?nicho=${pasta.nicho!.slug}')
                  : null,
            ),
            if (!provider.recolhida(pasta.nicho)) ...[
              if (pasta.servicos.isEmpty) const _PastaVazia(),
              for (final servico in pasta.servicos)
                _ServicoTile(
                  servico: servico,
                  onTap: provider.ehProprietario
                      ? () => _abrir('/mais/servicos/${servico.id}')
                      : null,
                ),
            ],
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ServicoTile extends StatelessWidget {
  const _ServicoTile({required this.servico, required this.onTap});

  final Servico servico;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      // o inativo vai em inkMuted, com o selo neutro no fim
      titleTextStyle: servico.ativo
          ? null
          : textos.titleMedium?.copyWith(color: cores.inkMuted),
      title: Text(servico.nome),
      // o porte e a duração são detalhe (inkMuted); o preço vai em ink
      subtitle: Text.rich(
        TextSpan(
          children: [
            if (servico.porte != null)
              TextSpan(text: '${servico.porte!.nome} · '),
            TextSpan(text: '${servico.duracao} min · '),
            TextSpan(
              text: formatarDinheiro(servico.preco),
              style: TextStyle(
                color: servico.ativo ? cores.ink : cores.inkMuted,
              ),
            ),
          ],
        ),
      ),
      trailing: servico.ativo
          ? (onTap == null ? null : const Icon(Icons.chevron_right_rounded))
          : SeloDeStatus(texto: 'Inativo', cor: cores.inkMuted),
    );
  }
}

class _CabecalhoDaPasta extends StatelessWidget {
  const _CabecalhoDaPasta({
    required this.nicho,
    required this.quantidade,
    required this.recolhida,
    required this.onAlternar,
    required this.onNovo,
  });

  // null é a pasta dos nichos que o negócio deixou
  final Nicho? nicho;
  final int quantidade;
  final bool recolhida;
  final VoidCallback onAlternar;
  final VoidCallback? onNovo;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final nome = nicho?.nome ?? 'Nichos removidos';

    // tocar no cabeçalho abre e fecha a pasta; o + cria serviço nela
    return InkWell(
      onTap: onAlternar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BrandSpacing.space4,
          BrandSpacing.space2,
          BrandSpacing.space2,
          BrandSpacing.space2,
        ),
        child: Row(
          children: [
            Icon(nicho?.icone ?? Icons.folder_off_rounded, color: cores.ink),
            const SizedBox(width: BrandSpacing.space3),
            Expanded(
              child: Text(
                nome,
                style: textos.titleSmall?.copyWith(color: cores.ink),
              ),
            ),
            Text(
              '$quantidade',
              style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
            ),
            if (onNovo != null)
              IconButton(
                onPressed: onNovo,
                tooltip: 'Novo serviço em $nome',
                icon: const Icon(Icons.add_rounded),
              ),
            Padding(
              padding: const EdgeInsets.all(BrandSpacing.space2),
              child: Icon(
                recolhida
                    ? Icons.expand_more_rounded
                    : Icons.expand_less_rounded,
                color: cores.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PastaVazia extends StatelessWidget {
  const _PastaVazia();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BrandSpacing.space4,
        0,
        BrandSpacing.space4,
        BrandSpacing.space3,
      ),
      child: Text(
        'Nenhum serviço nesta pasta.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: BrandColors.of(context).inkMuted),
      ),
    );
  }
}
