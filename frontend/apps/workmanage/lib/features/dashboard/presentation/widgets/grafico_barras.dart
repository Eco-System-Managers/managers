import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';

// um gráfico de barras mínimo, numa série só: barras finas em inkMuted,
// pontas arredondadas, sem eixo e sem grade. a última barra (hoje) é a de
// destaque, no azul; as outras ficam neutras. o rótulo embaixo é opcional e
// esparso: só alguns, para não virar uma fileira de números. valor é a
// altura relativa
class GraficoBarras extends StatelessWidget {
  const GraficoBarras({
    super.key,
    required this.valores,
    this.rotulos = const [],
    this.destaque,
    this.altura = 72,
  });

  // as alturas, em qualquer unidade; tudo zero vira uma linha de base
  final List<double> valores;

  // um por barra, ou vazio; só alguns são desenhados
  final List<String> rotulos;

  // a barra cheia; null é a última
  final int? destaque;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final cheia = destaque ?? valores.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: altura,
          child: CustomPaint(
            painter: _BarrasPainter(
              valores: valores,
              cheia: cheia,
              corDaCheia: colors.primary,
              corDasOutras: colors.onSurfaceVariant,
              corBase: colors.outline,
            ),
          ),
        ),
        if (rotulos.isNotEmpty) ...[
          const SizedBox(height: BrandSpacing.space1),
          Row(
            children: [
              for (var i = 0; i < rotulos.length; i++)
                Expanded(
                  child: Text(
                    _mostraRotulo(i) ? rotulos[i] : '',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: textos.labelSmall?.copyWith(
                      color: i == cheia
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // até 7 barras, todos os rótulos; acima disso, o primeiro, o último e
  // cerca de um a cada semana
  bool _mostraRotulo(int i) {
    final n = rotulos.length;
    if (n <= 7) return true;
    if (i == 0 || i == n - 1) return true;
    final passo = (n / 4).ceil();
    return i % passo == 0 && i < n - 2;
  }
}

class _BarrasPainter extends CustomPainter {
  const _BarrasPainter({
    required this.valores,
    required this.cheia,
    required this.corDaCheia,
    required this.corDasOutras,
    required this.corBase,
  });

  final List<double> valores;
  final int cheia;
  final Color corDaCheia;
  final Color corDasOutras;
  final Color corBase;

  @override
  void paint(Canvas canvas, Size size) {
    if (valores.isEmpty) return;
    final maior = valores.fold<double>(0, (m, v) => v > m ? v : m);
    final n = valores.length;
    // a barra ocupa 60% do espaço dela, no máximo 28 px, mínimo 3
    final espaco = size.width / n;
    final largura = (espaco * 0.6).clamp(3.0, 28.0);
    final raio = Radius.circular(largura / 2);
    final base = size.height - 1;

    canvas.drawLine(
      Offset(0, base),
      Offset(size.width, base),
      Paint()
        ..color = corBase
        ..strokeWidth = 1,
    );

    for (var i = 0; i < n; i++) {
      final v = valores[i];
      final alturaBarra = maior <= 0 ? 0.0 : (v / maior) * (size.height - 6);
      if (alturaBarra <= 0) continue;
      final x = espaco * i + (espaco - largura) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, base - alturaBarra, largura, alturaBarra),
        topLeft: raio,
        topRight: raio,
      );
      canvas.drawRRect(
        rect,
        Paint()..color = i == cheia ? corDaCheia : corDasOutras,
      );
    }
  }

  @override
  bool shouldRepaint(_BarrasPainter antigo) =>
      antigo.valores != valores ||
      antigo.cheia != cheia ||
      antigo.corDaCheia != corDaCheia ||
      antigo.corDasOutras != corDasOutras ||
      antigo.corBase != corBase;
}
