import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/features/empresa/empresa_provider.dart';

// a casca do app: a navegação inferior com as quatro abas (Início,
// Agenda/Quadro, Clientes e Mais), cada uma com a própria pilha
// (StatefulShellRoute). antes de mostrar as abas, carrega o
// negócio atual: é ele que diz o modo de agenda e o papel de quem entrou
class HomeShellPage extends ConsumerStatefulWidget {
  const HomeShellPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage> {
  @override
  void initState() {
    super.initState();
    // depois do primeiro build, com o provider já vivo pelo watch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(negocioAtualProvider).carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final negocio = ref.watch(negocioAtualProvider);
    final shell = widget.navigationShell;

    return ListenableBuilder(
      listenable: negocio,
      builder: (context, _) {
        if (!negocio.carregado) {
          final erro = negocio.erro;
          if (erro != null) {
            return Scaffold(
              body: EstadoErro(
                mensagem: erro.message,
                onTentarDeNovo: () => negocio.carregar(forcar: true),
              ),
            );
          }
          return const Scaffold(body: Carregando());
        }

        return Scaffold(
          body: shell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: shell.currentIndex,
            // tocar na aba atual volta para o começo da pilha dela
            onDestinationSelected: (index) => shell.goBranch(
              index,
              initialLocation: index == shell.currentIndex,
            ),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Início',
              ),
              NavigationDestination(
                icon: Icon(
                  negocio.isKanban
                      ? Icons.view_kanban_outlined
                      : Icons.calendar_month_outlined,
                ),
                selectedIcon: Icon(
                  negocio.isKanban ? Icons.view_kanban : Icons.calendar_month,
                ),
                // o rótulo segue o modo de agenda do negócio
                label: negocio.isKanban ? 'Quadro' : 'Agenda',
              ),
              const NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Clientes',
              ),
              const NavigationDestination(
                icon: Icon(Icons.more_horiz),
                selectedIcon: Icon(Icons.more_horiz),
                label: 'Mais',
              ),
            ],
          ),
        );
      },
    );
  }
}
