import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/features/agenda/presentation/pages/agenda_page.dart';
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:managers/features/kanban/presentation/pages/quadro_page.dart';

// a primeira aba segue o modo de agenda do negócio: horário marcado abre a
// agenda, esteira abre o quadro. o modo não muda depois do onboarding
class PrimeiraAbaPage extends ConsumerWidget {
  const PrimeiraAbaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final negocio = ref.watch(negocioAtualProvider);
    return ListenableBuilder(
      listenable: negocio,
      builder: (context, _) =>
          negocio.isKanban ? const QuadroPage() : const AgendaPage(),
    );
  }
}
