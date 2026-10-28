import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/estado_vazio.dart';

import '../../agenda_provider.dart';
import '../widgets/historico_cliente_card.dart';

// todos os atendimentos de um cliente, do mais recente para o mais antigo
class HistoricoClientePage extends ConsumerStatefulWidget {
  const HistoricoClientePage({super.key, required this.clienteId});

  final int clienteId;

  @override
  ConsumerState<HistoricoClientePage> createState() =>
      _HistoricoClientePageState();
}

class _HistoricoClientePageState extends ConsumerState<HistoricoClientePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(historicoClienteProvider(widget.clienteId)).carregar();
      }
    });
  }

  Future<void> _abrir(int id) async {
    await context.push('/agenda/$id');
    if (mounted) {
      ref.read(historicoClienteProvider(widget.clienteId)).carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(historicoClienteProvider(widget.clienteId));

    return Scaffold(
      appBar: AppBar(title: const Text('Atendimentos')),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          if (!provider.carregado) {
            final erro = provider.erro;
            if (erro != null) {
              return EstadoErro(
                mensagem: erro.message,
                onTentarDeNovo: provider.carregar,
              );
            }
            return const Carregando();
          }
          if (provider.agendamentos.isEmpty) {
            return const EstadoVazio(
              icone: Icons.event_note_rounded,
              titulo: 'Nenhum atendimento ainda',
            );
          }
          return RefreshIndicator(
            onRefresh: provider.carregar,
            child: ListView.separated(
              itemCount: provider.agendamentos.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final a = provider.agendamentos[index];
                return HistoricoItem(agendamento: a, onTap: () => _abrir(a.id));
              },
            ),
          );
        },
      ),
    );
  }
}
