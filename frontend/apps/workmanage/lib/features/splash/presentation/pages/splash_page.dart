import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/brand.dart';
import '../../../../core/widgets/auth_logo.dart';
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

    // fora do app, a marca: o marinho com o símbolo branco nos dois temas,
    // igual à splash nativa, que ela continua sem salto
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: estiloDaBarraDeAbertura,
      child: Scaffold(
        backgroundColor: BrandColors.brandNavy,
        body: Center(
          // redesenha quando a rota é decidida: a animação para de repetir e
          // termina o ciclo que está rodando; a navegação sai no fim dele
          child: ListenableBuilder(
            listenable: _provider,
            builder: (context, _) => WorkManageLoader(
              size: 120,
              startFull: true,
              loop: !_provider.rotaDecidida,
              // pausa longa para dar destaque à marca. o primeiro ciclo,
              // que começa com o símbolo completo, dura 2 s; os seguintes,
              // com a entrada, 4,8 s
              pauseDuration: const Duration(milliseconds: 1200),
              color: BrandColors.light.onBrand,
              onCycleEnd: _provider.onAnimationCycleEnd,
            ),
          ),
        ),
      ),
    );
  }
}
