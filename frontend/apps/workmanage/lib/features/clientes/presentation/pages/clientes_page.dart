import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/widgets/avatar_iniciais.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/estado_vazio.dart';
import 'package:managers/core/widgets/mascara_formatter.dart';

import '../../clientes_provider.dart';
import '../providers/clientes_provider.dart';

// a lista de clientes: busca, paginação ao chegar no fim e puxar para
// atualizar. ficha e formulário abrem por cima; ao voltar, a lista é
// recarregada da API
class ClientesPage extends ConsumerStatefulWidget {
  const ClientesPage({super.key});

  @override
  ConsumerState<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends ConsumerState<ClientesPage> {
  final _buscaController = TextEditingController();
  final _scrollController = ScrollController();
  final _telefoneMascara = MascaraFormatter.dinamica(MascaraFormatter.telefone);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_aoRolar);
    // depois do primeiro build: o watch já está segurando o provider vivo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(clientesProvider).carregar();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _buscaController.dispose();
    super.dispose();
  }

  // perto do fim da lista, pede a próxima página
  void _aoRolar() {
    final posicao = _scrollController.position;
    if (posicao.pixels >= posicao.maxScrollExtent - 200) {
      ref.read(clientesProvider).carregarMais();
    }
  }

  // ficha e formulário podem ter mudado o cliente: a lista vem da API de novo
  Future<void> _abrir(String rota) async {
    await context.push(rota);
    if (mounted) ref.read(clientesProvider).carregar();
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a aba estiver aberta
    final provider = ref.watch(clientesProvider);

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Clientes')),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _abrir('/clientes/novo'),
            tooltip: 'Novo cliente',
            child: const Icon(Icons.person_add_alt_1),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _buscaController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: provider.buscar,
                  decoration: InputDecoration(
                    hintText: 'Nome, telefone, e-mail ou CPF',
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
              Expanded(child: _corpo(provider)),
            ],
          ),
        );
      },
    );
  }

  Widget _corpo(ClientesProvider provider) {
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

    if (provider.clientes.isEmpty) {
      final buscando = provider.busca.isNotEmpty;
      return EstadoVazio(
        icone: Icons.people_outline,
        titulo: buscando ? 'Nada encontrado' : 'Nenhum cliente ainda',
        mensagem: buscando
            ? 'Tente outro nome, telefone, e-mail ou CPF.'
            : 'Cadastre quem você atende: nome e telefone bastam.',
        acao: buscando
            ? null
            : FilledButton.icon(
                onPressed: () => _abrir('/clientes/novo'),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Cadastrar cliente'),
              ),
      );
    }

    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: provider.carregar,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 88),
        // uma linha a mais no fim: o indicador da próxima página ou o erro
        itemCount: provider.clientes.length + 1,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == provider.clientes.length) {
            return _Rodape(
              carregandoMais: provider.carregandoMais,
              erro: provider.errorMessage,
              onTentarDeNovo: provider.carregarMais,
              total: provider.total,
              mostrando: provider.clientes.length,
            );
          }
          final cliente = provider.clientes[index];
          return ListTile(
            leading: AvatarIniciais(
              nome: cliente.nome,
              fotoUrl: cliente.fotoUrl,
            ),
            title: Text(cliente.nome),
            subtitle: Text(_telefoneMascara.aplicar(cliente.telefone)),
            trailing: cliente.veioDoApp
                ? Chip(
                    label: const Text('App'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colors.secondaryContainer,
                  )
                : const Icon(Icons.chevron_right),
            onTap: () => _abrir('/clientes/${cliente.id}'),
          );
        },
      ),
    );
  }
}

// o que aparece depois do último cliente: a próxima página carregando, o
// erro dela, ou quantos já estão na tela
class _Rodape extends StatelessWidget {
  const _Rodape({
    required this.carregandoMais,
    required this.erro,
    required this.onTentarDeNovo,
    required this.total,
    required this.mostrando,
  });

  final bool carregandoMais;
  final String? erro;
  final VoidCallback onTentarDeNovo;
  final int total;
  final int mostrando;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (carregandoMais) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (erro != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(erro!, style: TextStyle(color: colors.error)),
            TextButton(
              onPressed: onTentarDeNovo,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        '$mostrando de $total',
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.onSurfaceVariant),
      ),
    );
  }
}
