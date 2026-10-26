import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/estado_vazio.dart';

import '../../domain/entities/servico.dart';
import '../../servicos_provider.dart';
import '../providers/servicos_provider.dart';

// o catálogo: busca, filtro de inativos e a lista. criar e editar abrem o
// formulário por cima; ao voltar, a lista é recarregada da API
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
                  child: const Icon(Icons.add),
                )
              : null,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _buscaController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: provider.buscar,
                  decoration: InputDecoration(
                    hintText: 'Buscar serviço',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _buscaController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    provider.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
        icone: Icons.design_services_outlined,
        titulo: buscando ? 'Nada encontrado' : 'Nenhum serviço ainda',
        mensagem: buscando
            ? 'Tente outro nome.'
            : 'Cadastre o que o seu negócio oferece: nome, duração e preço.',
        acao: provider.ehProprietario && !buscando
            ? FilledButton.icon(
                onPressed: () => _abrir('/mais/servicos/novo'),
                icon: const Icon(Icons.add),
                label: const Text('Cadastrar serviço'),
              )
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: provider.carregar,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
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
}

class _ServicoTile extends StatelessWidget {
  const _ServicoTile({required this.servico, required this.onTap});

  final Servico servico;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onTap,
      title: Text(
        servico.nome,
        style: servico.ativo
            ? null
            : TextStyle(
                color: colors.outline,
                decoration: TextDecoration.lineThrough,
              ),
      ),
      subtitle: Text(
        '${servico.duracao} min · ${formatarDinheiro(servico.preco)}',
      ),
      trailing: servico.ativo
          ? (onTap == null ? null : const Icon(Icons.chevron_right))
          : Chip(
              label: const Text('Inativo'),
              visualDensity: VisualDensity.compact,
              backgroundColor: colors.surfaceContainerHighest,
            ),
    );
  }
}
