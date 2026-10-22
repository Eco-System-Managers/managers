import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// painel branco arredondado das telas de auth (login e cadastro).
// ao entrar numa tela nova, o painel parte da altura do painel anterior
// e cresce/encolhe até o tamanho do próprio conteúdo, que aparece em fade.
// na volta (pop) tudo roda ao contrário, porque segue a animação da rota.
class AuthPanel extends StatefulWidget {
  const AuthPanel({super.key, required this.child});

  final Widget child;

  // altura do último painel desenhado na tela: é de onde o próximo parte
  static double? _lastHeight;

  @override
  State<AuthPanel> createState() => _AuthPanelState();
}

class _AuthPanelState extends State<AuthPanel> {
  // capturada quando a tela é criada: altura do painel da tela anterior
  // (null quando não havia painel antes, ex.: vindo da splash)
  final double? _fromHeight = AuthPanel._lastHeight;

  // o conteúdo só aparece depois que o painel já cresceu boa parte
  static const _contentFade = Interval(0.4, 1, curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final routeAnimation = ModalRoute.of(context)?.animation;
    final animation = (routeAnimation == null || reduceMotion)
        ? kAlwaysCompleteAnimation
        : routeAnimation;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: AnimatedBuilder(
        animation: animation,
        // o conteúdo é montado uma vez; o builder só muda a altura
        child: FadeTransition(
          opacity: animation.drive(CurveTween(curve: _contentFade)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: widget.child,
          ),
        ),
        builder: (context, content) => _PanelHeight(
          from: _fromHeight,
          t: Curves.easeInOutCubic.transform(animation.value),
          onLayout: (height) => AuthPanel._lastHeight = height,
          child: content,
        ),
      ),
    );
  }
}

// mede a altura natural do conteúdo e ocupa uma altura intermediária
// entre [from] e ela, conforme [t] (0 = from, 1 = altura do conteúdo).
// o que passar da altura atual é recortado (o conteúdo não é espremido).
class _PanelHeight extends SingleChildRenderObjectWidget {
  const _PanelHeight({
    required this.from,
    required this.t,
    required this.onLayout,
    super.child,
  });

  final double? from;
  final double t;
  final ValueChanged<double> onLayout;

  @override
  _RenderPanelHeight createRenderObject(BuildContext context) =>
      _RenderPanelHeight(from, t, onLayout);

  @override
  void updateRenderObject(BuildContext context, _RenderPanelHeight render) {
    render
      ..from = from
      ..t = t
      ..onLayout = onLayout;
  }
}

class _RenderPanelHeight extends RenderProxyBox {
  _RenderPanelHeight(this._from, this._t, this.onLayout);

  ValueChanged<double> onLayout;

  double? _from;
  set from(double? value) {
    if (value == _from) return;
    _from = value;
    markNeedsLayout();
  }

  double _t;
  set t(double value) {
    if (value == _t) return;
    _t = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    // largura fixa, altura livre: o conteúdo fica do tamanho natural dele
    child!.layout(
      BoxConstraints.tightFor(width: constraints.maxWidth),
      parentUsesSize: true,
    );
    final natural = child!.size.height;
    final from = _from ?? natural;
    size = constraints.constrain(
      Size(constraints.maxWidth, from + (natural - from) * _t),
    );
    // registra a altura visível: é ela que o próximo painel vai continuar
    onLayout(size.height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      super.paint,
    );
  }
}
