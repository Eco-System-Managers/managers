import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/widgets/botao_de_rodape.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/folha.dart';

import '../../empresa_provider.dart';
import '../widgets/nicho_visual.dart';
import '../widgets/nichos_grade.dart';

// troca os nichos do negócio dentro da área dele. tirar um nicho exclui
// (inativa) os serviços dele: a tela avisa quantos antes de salvar
class NichosPage extends ConsumerWidget {
  const NichosPage({super.key});

  Future<void> _salvar(BuildContext context, WidgetRef ref) async {
    final provider = ref.read(nichosProvider);

    final afetados = await provider.contarServicosAfetados();
    if (afetados == null || !context.mounted) return;

    if (afetados > 0) {
      final ok = await confirmar(
        context,
        titulo: 'Remover nicho',
        mensagem: _avisoDeRemocao(afetados, nomeDosNichos(provider.removidos)),
        textoConfirmar: 'Remover',
        destrutivo: true,
      );
      if (!ok || !context.mounted) return;
    }

    await provider.salvar();
  }

  String _avisoDeRemocao(int afetados, String nichos) {
    final servicos = afetados == 1
        ? '1 serviço de $nichos será excluído'
        : '$afetados serviços de $nichos serão excluídos';
    return '$servicos e não poderá${afetados == 1 ? '' : 'ão'} mais ser '
        'agendado${afetados == 1 ? '' : 's'}. Os agendamentos que já existem '
        'continuam.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(nichosProvider);
    final colors = Theme.of(context).colorScheme;
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nichos')),
      // o salvar fica fixo embaixo, fora da rolagem
      bottomNavigationBar: ListenableBuilder(
        listenable: provider,
        builder: (context, _) => BotaoDeRodape(
          texto: 'Salvar',
          onPressed: provider.podeSalvar ? () => _salvar(context, ref) : null,
        ),
      ),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          // salvou: avisa e fecha
          if (provider.salvo) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Nichos salvos')));
              context.pop();
            });
          }

          final area = provider.area;

          return comBotaoDeRodape(
            SingleChildScrollView(
              padding: paddingDaPagina(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Escolha de 1 a 4 nichos da mesma área. Com 2 ou mais, '
                    'os serviços ficam em pastas, uma por nicho.',
                    style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
                  ),
                  const SizedBox(height: BrandSpacing.space4),
                  if (provider.errorMessage != null) ...[
                    Text(
                      provider.errorMessage!,
                      style: textos.bodyMedium?.copyWith(color: colors.error),
                    ),
                    const SizedBox(height: BrandSpacing.space4),
                  ],
                  if (area != null)
                    NichosGrade(
                      escolhidos: provider.escolhidos,
                      areas: [area],
                      onAlternar: provider.isLoading ? null : provider.alternar,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
