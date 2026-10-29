import 'package:flutter/material.dart';

import '../theme/brand.dart';

// conteúdo de sucesso reutilizável: ícone, título, mensagem e uma barra
// que enche durante [duration]; ao terminar, chama [onDone].
// não monta Scaffold nem navega sozinho: quem usa encaixa onde quiser
// e decide para onde ir (ex.: voltar para o login)
class SuccessView extends StatelessWidget {
  const SuccessView({
    super.key,
    required this.title,
    required this.message,
    required this.onDone,
    this.duration = const Duration(seconds: 3),
    this.icon = Icons.check_circle_outline_rounded,
  });

  final String title;
  final String message;
  final VoidCallback onDone;
  final Duration duration;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    return Column(
      // ocupa só a altura do conteúdo, para caber no painel de quem usa
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // deu certo: o ícone é status, não ação
        Icon(icon, size: 72, color: cores.success),

        const SizedBox(height: BrandSpacing.space4),

        Text(
          title,
          textAlign: TextAlign.center,
          style: BrandText.h2.copyWith(color: cores.ink),
        ),

        const SizedBox(height: BrandSpacing.space2),

        Text(
          message,
          textAlign: TextAlign.center,
          style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
        ),

        const SizedBox(height: BrandSpacing.space5),

        // barra que enche de 0 a 1 durante a duração: mostra ao usuário
        // que ele vai ser redirecionado. o onEnd só dispara se o widget
        // ainda estiver na tela, então não precisa cancelar nada
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: duration,
          onEnd: onDone,
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            borderRadius: BrandRadius.smAll,
          ),
        ),
      ],
    );
  }
}
