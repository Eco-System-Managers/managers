import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/work_manage_loader.dart';
import '../view_models/splash_view_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.viewModel});

  final SplashViewModel viewModel;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onChange);
    widget.viewModel.init();
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final route = widget.viewModel.destination;
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
          onCycleEnd: widget.viewModel.onAnimationCycleEnd,
        ),
      ),
    );
  }
}
