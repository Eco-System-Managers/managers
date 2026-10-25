import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/estado_vazio.dart';

import '../../agenda_provider.dart';
import '../providers/pendencias_provider.dart';

// atendimentos que já passaram e não foram cobrados. tocar abre a ficha
// para cobrar; ao voltar, a lista é recarregada
class PendenciasPage extends ConsumerStatefulWidget {
  const PendenciasPage({super.key});

  @override
  ConsumerState<PendenciasPage> createState() => _PendenciasPageState();
}

class _PendenciasPageState extends ConsumerState<PendenciasPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(pendenciasProvider).carregar();
    });
  }

  Future<void> _abrir(int id) async {
    await context.push('/agenda/$id');
    if (mounted) ref.read(pendenciasProvider).carregar();
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(pendenciasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cobranças pendentes')),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) => _corpo(provider),
      ),
    );
  }

  Widget _corpo(PendenciasProvider provider) {
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

    if (provider.pendencias.isEmpty) {
      return const EstadoVazio(
        icone: Icons.task_alt,
        titulo: 'Nada pendente',
        mensagem: 'Todo atendimento que já passou foi cobrado.',
      );
    }

    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: provider.carregar,
      child: ListView.separated(
        itemCount: provider.pendencias.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final p = provider.pendencias[index];
          return ListTile(
            leading: Icon(Icons.schedule, color: colors.error),
            title: Text(p.clienteNome),
            subtitle: Text('${formatarData(p.data)} · ${p.servicoNome}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatarDinheiro(p.valor),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (p.origemAgenda) const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            // o kanban não está neste app ainda: só a agenda abre
            onTap: p.origemAgenda ? () => _abrir(p.id) : null,
          );
        },
      ),
    );
  }
}
