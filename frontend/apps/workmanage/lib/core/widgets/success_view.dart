import 'package:flutter/material.dart';

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
    this.icon = Icons.check_circle_outline,
  });

  final String title;
  final String message;
  final VoidCallback onDone;
  final Duration duration;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      // ocupa só a altura do conteúdo, para caber no painel de quem usa
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 72, color: colors.primary),

        const SizedBox(height: 16),

        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 8),

        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),

        const SizedBox(height: 24),

        // barra que enche de 0 a 1 durante a duração: mostra ao usuário
        // que ele vai ser redirecionado. o onEnd só dispara se o widget
        // ainda estiver na tela, então não precisa cancelar nada
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: duration,
          onEnd: onDone,
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
