import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/work_manage_loader.dart';
import '../providers/splash_provider.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.provider});

  final SplashProvider provider;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onChange);
    widget.provider.init();
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final route = widget.provider.destination;
    if (route != null && mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
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
          onCycleEnd: widget.provider.onAnimationCycleEnd,
        ),
      ),
    );
  }
}
