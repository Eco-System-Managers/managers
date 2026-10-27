import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/botao_de_rodape.dart';
import 'package:managers/core/widgets/folha.dart';

import '../../empresa_provider.dart';
import '../widgets/horario_dia_card.dart';

// edita os dias e horários de funcionamento: os mesmos cards do onboarding
class HorariosPage extends ConsumerStatefulWidget {
  const HorariosPage({super.key});

  @override
  ConsumerState<HorariosPage> createState() => _HorariosPageState();
}

class _HorariosPageState extends ConsumerState<HorariosPage> {
  @override
  void initState() {
    super.initState();
    // depois do primeiro build: o watch já está segurando o provider vivo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(horariosProvider).carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(horariosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Horários')),
      // o salvar fica fixo embaixo, fora da rolagem
      bottomNavigationBar: ListenableBuilder(
        listenable: provider,
        builder: (context, _) => BotaoDeRodape(
          texto: 'Salvar',
          onPressed: provider.isLoading || !provider.carregado
              ? null
              : provider.salvar,
        ),
      ),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          if (provider.salvo) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Horários salvos')));
              context.pop();
            });
          }

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

          final colors = Theme.of(context).colorScheme;

          return comBotaoDeRodape(
            SingleChildScrollView(
              padding: paddingDaPagina(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    provider.isKanban
                        ? 'Marque os dias abertos, o horário e quantos '
                              'atendimentos cabem em cada dia.'
                        : 'Marque os dias abertos e o horário de cada um.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),

                  const SizedBox(height: 16),

                  for (final horario in provider.horarios) ...[
                    HorarioDiaCard(
                      horario: horario,
                      isKanban: provider.isKanban,
                      erro: provider.erroDoDia(horario),
                      enabled: !provider.isLoading,
                      onChanged: provider.atualizarHorario,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (provider.errorMessage != null)
                    Text(
                      provider.errorMessage!,
                      style: TextStyle(color: colors.error),
                    ),
                  // espaço para o fim da lista passar da sombra do botão
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
