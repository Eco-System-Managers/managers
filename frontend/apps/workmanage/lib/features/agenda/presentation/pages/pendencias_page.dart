import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
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

  Future<void> _abrir(String rota) async {
    await context.push(rota);
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
        icone: Icons.task_alt_rounded,
        titulo: 'Nada pendente',
        mensagem: 'Todo atendimento que já passou foi cobrado.',
      );
    }

    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: provider.carregar,
      child: ListView.separated(
        itemCount: provider.pendencias.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final p = provider.pendencias[index];
          return ListTile(
            // cobrança pendente é status de atenção, não erro
            leading: Icon(Icons.schedule_rounded, color: cores.warning),
            title: Text(p.clienteNome),
            subtitle: Text('${formatarData(p.data)} · ${p.servicoNome}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatarDinheiro(p.valor), style: textos.titleMedium),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
            // cada origem tem a própria ficha
            onTap: () =>
                _abrir(p.origemAgenda ? '/agenda/${p.id}' : '/quadro/${p.id}'),
          );
        },
      ),
    );
  }
}
