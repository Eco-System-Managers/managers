import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/work_manage_loader.dart';
import '../../splash_provider.dart';
import '../providers/splash_provider.dart';

// a tela lê o provider pelo ref (Riverpod), como as demais
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  late final SplashProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = ref.read(splashProvider);
    _provider.addListener(_onChange);
    _provider.init();
  }

  @override
  void dispose() {
    _provider.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final route = _provider.destination;
    if (route != null && mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    ref.watch(splashProvider);

    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0E0F12) : const Color(0xFFF5F6F9),
      body: Center(
        child: WorkManageLoader(
          size: 120,
          startFull: true,
          // pausa longa para dar destaque à marca: ciclo da splash ≈ 3 s
          pauseDuration: const Duration(milliseconds: 1200),
          color: dark ? Colors.white : WorkManageLoader.brandBlue,
          onCycleEnd: _provider.onAnimationCycleEnd,
        ),
      ),
    );
  }
}
