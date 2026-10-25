import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Etapa da animação: duração autoral (coreografia) e duração real de reprodução.
class _Seg {
  const _Seg(this.auth, this.play);
  final double auth;
  final double play;
}

// Desenho, Ponto, Pausa, Saída — mesmos tempos do protótipo.
// Só a reprodução da pausa varia (vem de [WorkManageLoader.pauseDuration]);
// o tempo autoral fica igual, então a coreografia não muda, só desacelera.
List<_Seg> _scenesWith(double pausePlay) => [
  const _Seg(1.2, 2.4),
  const _Seg(0.5, 0.5),
  _Seg(0.9, pausePlay),
  const _Seg(0.8, 0.8),
];

// Marcos autorais (segundos).
const _cPonto = 1.2, _cPausa = 1.7, _cSaida = 2.6, _cEnd = 3.4;

/// Logo animado de carregamento do Work Manage.
///
/// [size] é o lado maior do logo. [startFull] começa com o logo completo
/// (use na splash para continuar a imagem da splash nativa sem salto).
/// [pauseDuration] é quanto tempo o logo fica completo antes de sair
/// (aumente para dar mais destaque à marca).
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

  static const brandBlue = Color(0xFF003FB1);

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
    final color = widget.color ?? WorkManageLoader.brandBlue;
    final w = widget.size;
    final h = widget.size * 52 / 76;
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
              final t = reduceMotion ? 2.2 : _authored(_c.value * _playTotal);
              return CustomPaint(painter: _LogoPainter.at(t, color));
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

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.color, this.lo, this.ro, this.dot, this.breath);

  /// lo / ro: 1 = escondido, 0 = desenhado, -1 = apagado.
  factory _LogoPainter.at(double t, Color color) {
    const draw = Curves.easeInOutCubic;
    final before = t < _cSaida;
    return _LogoPainter(
      color,
      before
          ? _tw(t, 1, 0, 0, 1.0, draw)
          : _tw(t, 0, -1, _cSaida, _cEnd - 0.15, draw),
      before
          ? _tw(t, 1, 0, 0.2, _cPonto, draw)
          : _tw(t, 0, -1, _cSaida + 0.1, _cEnd - 0.05, draw),
      before
          ? _tw(t, 0, 1, _cPonto - 0.1, _cPonto + 0.45, Curves.easeOutBack)
          : _tw(t, 1, 0, _cSaida, _cSaida + 0.4, draw),
      before
          ? _tw(t, 1, 1.035, _cPausa - 0.2, _cSaida, Curves.easeInOutSine)
          : _tw(t, 1.035, 0.96, _cSaida, _cEnd, Curves.easeInOutSine),
    );
  }

  final Color color;
  final double lo, ro, dot, breath;

  static const _tau = 2 * math.pi;
  static const _l = Offset(38, 32), _r = Offset(62, 32);
  static const _layer = Rect.fromLTWH(-20, -20, 140, 104);

  void _arc(Canvas c, Offset center, double start, double o, Paint p) {
    final a0 = _tau * math.max(0.0, -o);
    final a1 = _tau * math.min(1.0, 1 - o);
    final sweep = a1 - a0;
    if (sweep <= 0.001) return;
    if (sweep >= _tau - 0.001) {
      c.drawCircle(center, 22, p);
    } else {
      c.drawArc(
        Rect.fromCircle(center: center, radius: 22),
        start + a0,
        sweep,
        false,
        p,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const vb = Rect.fromLTWH(12, 6, 76, 52);
    final s = math.min(size.width / vb.width, size.height / vb.height);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s * breath);
    canvas.translate(-vb.center.dx, -vb.center.dy);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = color;
    final clear = Paint()..blendMode = BlendMode.clear;

    // Anéis + corte horizontal central.
    canvas.saveLayer(_layer, Paint());
    _arc(canvas, _l, math.pi, lo, ring);
    _arc(canvas, _r, 0, ro, ring);
    canvas.drawRect(const Rect.fromLTWH(-10, 30.6, 120, 2.8), clear);
    canvas.restore();

    // Ponto interno, recortado pelo anel da direita.
    if (dot > 0) {
      canvas.saveLayer(_layer, Paint());
      canvas.drawCircle(_l, 15.2 * dot, Paint()..color = color);
      canvas.drawCircle(
        _r,
        22,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13.6
          ..blendMode = BlendMode.clear,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter o) =>
      o.lo != lo ||
      o.ro != ro ||
      o.dot != dot ||
      o.breath != breath ||
      o.color != color;
}
