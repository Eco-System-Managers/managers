import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/brand.dart';
import 'brand_logo.dart';

/// Etapa da animação: duração autoral (coreografia) e duração real de reprodução.
class _Seg {
  const _Seg(this.auth, this.play);
  final double auth;
  final double play;
}

// Entrada, Gota, Pausa, Saída.
// Só a reprodução da pausa varia (vem de [WorkManageLoader.pauseDuration]);
// o tempo autoral fica igual, então a coreografia não muda, só desacelera.
List<_Seg> _scenesWith(double pausePlay) => [
  const _Seg(1.2, 2.4),
  const _Seg(0.5, 0.5),
  _Seg(0.9, pausePlay),
  const _Seg(0.8, 0.8),
];

// Marcos autorais (segundos).
const _cGota = 1.2, _cPausa = 1.7, _cSaida = 2.6, _cEnd = 3.4;

/// O símbolo do Work Manage animado, para o carregamento.
///
/// As duas hastes entram, a gota azul chega por cima (o cliente que chega
/// para o próximo horário), o símbolo respira e sai. A geometria é a de
/// `design/07-assets/simbolos-svg/w-mark.svg`, sem nenhum ponto alterado.
///
/// [size] é a largura do símbolo. Sem [color], é o símbolo colorido (marinho
/// e azul) sobre fundo claro e o branco sobre fundo escuro, como o
/// [BrandLogo]; com [color], a versão de uma cor só. [startFull] começa com o
/// símbolo completo (use na splash para continuar a imagem da splash nativa
/// sem salto). [pauseDuration] é quanto tempo o símbolo fica completo antes
/// de sair (aumente para dar mais destaque à marca).
class WorkManageLoader extends StatefulWidget {
  const WorkManageLoader({
    super.key,
    this.color,
    this.size = 120,
    this.loop = true,
    this.startFull = false,
    this.pauseDuration = const Duration(milliseconds: 900),
    this.onCycleEnd,
  }) : assert(pauseDuration > Duration.zero);

  final Color? color;
  final double size;
  final bool loop;
  final bool startFull;
  final Duration pauseDuration;
  final VoidCallback? onCycleEnd;

  @override
  State<WorkManageLoader> createState() => _WorkManageLoaderState();
}

class _WorkManageLoaderState extends State<WorkManageLoader>
    with SingleTickerProviderStateMixin {
  late final List<_Seg> _scenes = _scenesWith(
    widget.pauseDuration.inMilliseconds / 1000,
  );
  late final double _playTotal = _scenes.fold(0.0, (a, s) => a + s.play);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_playTotal * 1000).round()),
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      widget.onCycleEnd?.call();
      if (widget.loop && mounted) _c.forward(from: 0);
    });
    final startPlay = widget.startFull
        ? _scenes[0].play + _scenes[1].play
        : 0.0;
    _c.forward(from: startPlay / _playTotal);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _authored(double playT) {
    var a = 0.0, p = 0.0;
    for (final s in _scenes) {
      if (playT <= p + s.play) return a + (playT - p) / s.play * s.auth;
      a += s.auth;
      p += s.play;
    }
    return a;
  }

  @override
  Widget build(BuildContext context) {
    // sem cor pedida, a versão que o BrandLogo usaria sobre este fundo
    final Color hastes, gota;
    if (widget.color != null) {
      hastes = gota = widget.color!;
    } else {
      final fundo = Theme.of(context).scaffoldBackgroundColor;
      final colorido = BrandLogo.corPeloFundo(fundo) == CorDoLogo.colorido;
      final branco = BrandColors.light.onBrand;
      hastes = colorido ? BrandColors.brandNavy : branco;
      gota = colorido ? BrandColors.brandBlue : branco;
    }
    final w = widget.size;
    final h =
        widget.size *
        _SimboloPainter.viewBox.height /
        _SimboloPainter.viewBox.width;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Semantics(
      label: 'Carregando',
      child: SizedBox(
        width: w,
        height: h,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) {
              // sem animação, o símbolo completo parado
              final t = reduceMotion ? 2.2 : _authored(_c.value * _playTotal);
              return CustomPaint(painter: _SimboloPainter.at(t, hastes, gota));
            },
          ),
        ),
      ),
    );
  }
}

double _tw(
  double t,
  double from,
  double to,
  double start,
  double end,
  Curve curve,
) {
  final x = ((t - start) / (end - start)).clamp(0.0, 1.0);
  return from + (to - from) * curve.transform(x);
}

// uma parte do símbolo num instante: quanto aparece e quanto está deslocada
// (em fração da altura do símbolo; + é para baixo)
class _Parte {
  const _Parte(this.opacidade, this.deslocamento);
  final double opacidade;
  final double deslocamento;
}

class _SimboloPainter extends CustomPainter {
  _SimboloPainter(
    this.hastes,
    this.gota,
    this.parte1,
    this.parte2,
    this.parteGota,
    this.breath,
  );

  factory _SimboloPainter.at(double t, Color hastes, Color gota) {
    const entra = Curves.easeOutCubic;
    const sai = Curves.easeInCubic;
    final before = t < _cSaida;

    // as hastes sobem um pouco enquanto aparecem, uma depois da outra
    _Parte haste(double inicio, double fimDaSaida) => before
        ? _Parte(
            _tw(t, 0, 1, inicio, inicio + 0.8, entra),
            _tw(t, 0.12, 0, inicio, inicio + 0.8, entra),
          )
        : _Parte(_tw(t, 1, 0, _cSaida + 0.1, fimDaSaida, sai), 0);

    return _SimboloPainter(
      hastes,
      gota,
      haste(0, _cEnd - 0.15),
      haste(0.3, _cEnd - 0.05),
      // a gota chega de cima, com um leve assentamento; e é a primeira a sair
      before
          ? _Parte(
              _tw(t, 0, 1, _cGota - 0.1, _cGota + 0.25, entra),
              _tw(t, -0.35, 0, _cGota - 0.1, _cGota + 0.45, Curves.easeOutBack),
            )
          : _Parte(_tw(t, 1, 0, _cSaida, _cSaida + 0.4, sai), 0),
      before
          ? _tw(t, 1, 1.035, _cPausa - 0.2, _cSaida, Curves.easeInOutSine)
          : _tw(t, 1.035, 0.96, _cSaida, _cEnd, Curves.easeInOutSine),
    );
  }

  final Color hastes, gota;
  final _Parte parte1, parte2, parteGota;
  final double breath;

  // o viewBox de w-mark.svg
  static const viewBox = Rect.fromLTWH(0, 0, 188.11, 120);

  // os três caminhos de w-mark.svg, na ordem do arquivo: a gota (azul) e as
  // duas hastes (marinho)
  static final _gota = _caminho(
    'M 148.022,10.117 C 143.862,10.255 143.508,10.313 141.683,11.295 C 139.466,12.472 139.250,12.766 131.303,25.404 C 128.026,30.624 127.633,31.526 127.653,33.802 C 127.672,35.569 128.065,36.766 129.478,39.356 C 130.106,40.494 131.911,43.928 133.500,47.009 C 136.522,52.857 141.526,62.060 142.409,63.375 C 144.038,65.828 147.453,66.691 150.200,65.357 C 151.927,64.513 152.005,64.395 157.971,53.995 C 159.697,50.973 163.171,44.752 165.683,40.160 C 170.392,31.526 171.727,29.113 174.807,23.755 C 177.633,18.810 178.026,17.908 178.104,16.299 C 178.241,13.728 176.986,11.628 174.650,10.549 L 173.532,10.019 L 162.739,10.0 C 156.813,10.0 150.180,10.058 148.022,10.117',
  );
  static final _haste1 = _caminho(
    'M 17.233,10.706 C 14.387,11.197 11.876,13.061 10.698,15.572 C 10.168,16.671 10.070,17.162 10.011,18.614 C 9.972,19.576 10.031,20.753 10.168,21.263 C 10.286,21.773 11.895,24.972 13.740,28.367 C 15.584,31.762 17.488,35.294 17.978,36.216 C 18.469,37.138 19.627,39.297 20.569,41.024 C 23.846,47.029 34.540,67.280 38.916,75.757 C 41.036,79.858 46.216,89.807 50.926,98.834 C 52.594,102.032 54.301,105.074 54.752,105.604 C 57.088,108.449 60.345,110.0 63.975,110.0 C 65.977,110.0 67.508,109.627 69.391,108.685 C 72.099,107.331 72.806,106.487 79.046,97.146 C 82.264,92.319 84.874,88.198 85.129,87.531 C 85.522,86.550 85.600,86.000 85.600,84.195 C 85.600,81.722 85.404,81.036 83.775,78.229 C 74.101,61.334 61.935,39.729 49.297,16.946 C 47.237,13.198 44.411,11.197 40.565,10.706 C 38.681,10.470 18.606,10.470 17.233,10.706',
  );
  static final _haste2 = _caminho(
    'M 77.280,10.726 C 74.297,11.040 71.707,12.668 70.019,15.259 C 68.999,16.828 68.567,18.536 68.705,20.459 C 68.862,22.872 68.332,21.754 78.497,41.122 C 84.442,52.464 90.388,64.101 106.126,95.184 C 108.638,100.149 110.934,104.564 111.248,105.015 C 112.641,107.056 115.506,109.018 118.096,109.705 C 119.509,110.078 122.217,110.078 123.689,109.705 C 125.651,109.195 127.613,108.116 129.124,106.703 C 130.263,105.624 131.479,103.936 136.130,96.950 C 142.508,87.394 142.723,86.981 142.684,83.901 C 142.664,81.958 142.233,80.447 140.997,78.210 C 135.051,67.299 126.201,51.718 112.602,28.269 C 110.914,25.345 108.579,21.302 107.382,19.262 C 104.851,14.866 103.379,13.120 101.259,12.021 C 98.532,10.588 98.689,10.608 87.975,10.608 C 82.696,10.608 77.869,10.667 77.280,10.726',
  );

  // lê os comandos absolutos M, L e C dos caminhos acima
  static Path _caminho(String d) {
    final partes = RegExp(r'[MLC]|-?\d+(?:\.\d+)?')
        .allMatches(d)
        .map((m) => m.group(0)!)
        .toList();
    final path = Path();
    var i = 0;
    var comando = 'M';
    double numero() => double.parse(partes[i++]);
    while (i < partes.length) {
      final p = partes[i];
      if (p == 'M' || p == 'L' || p == 'C') {
        comando = p;
        i++;
        continue;
      }
      switch (comando) {
        case 'M':
          path.moveTo(numero(), numero());
          // pares depois de um M são linhas, como no SVG
          comando = 'L';
        case 'L':
          path.lineTo(numero(), numero());
        case 'C':
          path.cubicTo(
            numero(),
            numero(),
            numero(),
            numero(),
            numero(),
            numero(),
          );
      }
    }
    return path..close();
  }

  void _desenhar(Canvas canvas, Path caminho, Color cor, _Parte parte) {
    if (parte.opacidade <= 0.001) return;
    canvas.save();
    canvas.translate(0, parte.deslocamento * viewBox.height);
    canvas.drawPath(
      caminho,
      Paint()..color = cor.withValues(alpha: cor.a * parte.opacidade),
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(
      size.width / viewBox.width,
      size.height / viewBox.height,
    );

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s * breath);
    canvas.translate(-viewBox.center.dx, -viewBox.center.dy);
    _desenhar(canvas, _haste1, hastes, parte1);
    _desenhar(canvas, _haste2, hastes, parte2);
    _desenhar(canvas, _gota, gota, parteGota);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SimboloPainter o) =>
      o.parte1.opacidade != parte1.opacidade ||
      o.parte1.deslocamento != parte1.deslocamento ||
      o.parte2.opacidade != parte2.opacidade ||
      o.parte2.deslocamento != parte2.deslocamento ||
      o.parteGota.opacidade != parteGota.opacidade ||
      o.parteGota.deslocamento != parteGota.deslocamento ||
      o.breath != breath ||
      o.hastes != hastes ||
      o.gota != gota;
}
