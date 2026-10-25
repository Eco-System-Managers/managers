import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home_provider.dart';

// a home provisória da fase 0: prova que o ciclo fecha (sessão guardada,
// splash decide, logout volta ao login). a home de verdade, com a
// navegação inferior, é a fase 1
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final home = ref.watch(homeProvider);
    final colors = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: home,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Work Manage'),
            actions: [
              IconButton(
                tooltip: 'Sair',
                icon: const Icon(Icons.logout),
                onPressed: home.saindo ? null : home.sair,
              ),
            ],
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 64,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    home.empresa,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Seu negócio está configurado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
