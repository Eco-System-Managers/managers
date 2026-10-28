import 'package:flutter/material.dart';

// as cores do Design System (design/tokens/tokens.json → color.tokens), uma
// instância por tema. o ColorScheme do Material (theme.dart) é montado a
// partir delas; esta extensão guarda o que ele não cobre: blueSoft, inkMuted,
// success, warning, os fundos e a borda. na tela: BrandColors.of(context)
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.navy,
    required this.blue,
    required this.blueSoft,
    required this.bg,
    required this.bg2,
    required this.border,
    required this.ink,
    required this.inkMuted,
    required this.onBrand,
    required this.success,
    required this.warning,
    required this.danger,
  });

  // o marinho da marca: os traços dos símbolos, a wordmark e o fundo do
  // ícone do app. não muda entre temas
  final Color navy;

  // a cor da ação: botão primário, link, estado ativo e a peça azul do
  // símbolo. no escuro clareia para dar 5.7:1 sobre o fundo
  final Color blue;

  // fundo suave ligado ao azul: badge, linha selecionada, destaque de bloco.
  // nunca para texto
  final Color blueSoft;

  // fundo da página e dos cartões
  final Color bg;

  // fundo secundário: cabeçalho de seção, campo de formulário, área do logo
  final Color bg2;

  // contorno de cartão, divisória e campo
  final Color border;

  // texto principal
  final Color ink;

  // texto secundário, legenda, rótulo e ícone neutro
  final Color inkMuted;

  // texto e logo em branco sobre o marinho ou o azul da marca
  final Color onBrand;

  // status: concluído, pendente e erro. só para status, nunca decoração
  final Color success;
  final Color warning;
  final Color danger;

  // as duas cores da marca, iguais nos dois temas. o botão primário usa o azul
  // da marca com texto branco (4.8:1) também no tema escuro: branco sobre o
  // azul clareado do escuro daria 3:1
  static const brandNavy = Color(0xFF0B1C35);
  static const brandBlue = Color(0xFF1B6AF3);

  static const light = BrandColors(
    navy: Color(0xFF0B1C35),
    blue: Color(0xFF1B6AF3),
    blueSoft: Color(0xFFE8F0FE),
    bg: Color(0xFFFFFFFF),
    bg2: Color(0xFFF3F6FD),
    border: Color(0xFFDFE6F1),
    ink: Color(0xFF0B1C35),
    inkMuted: Color(0xFF5A6A84),
    onBrand: Color(0xFFFFFFFF),
    success: Color(0xFF1A7F4B),
    warning: Color(0xFF9A5A00),
    danger: Color(0xFFB3261E),
  );

  static const dark = BrandColors(
    navy: Color(0xFF0B1C35),
    blue: Color(0xFF5A93FF),
    blueSoft: Color(0xFF15284D),
    bg: Color(0xFF0B1C35),
    bg2: Color(0xFF13254A),
    border: Color(0xFF2A3B5C),
    ink: Color(0xFFF2F6FC),
    inkMuted: Color(0xFF9FB2CC),
    onBrand: Color(0xFFFFFFFF),
    success: Color(0xFF4FC47F),
    warning: Color(0xFFF0B14A),
    danger: Color(0xFFFF7B72),
  );

  // as cores do tema atual
  static BrandColors of(BuildContext context) {
    final tema = Theme.of(context);
    return tema.extension<BrandColors>() ??
        (tema.brightness == Brightness.dark ? dark : light);
  }

  @override
  BrandColors copyWith({
    Color? navy,
    Color? blue,
    Color? blueSoft,
    Color? bg,
    Color? bg2,
    Color? border,
    Color? ink,
    Color? inkMuted,
    Color? onBrand,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return BrandColors(
      navy: navy ?? this.navy,
      blue: blue ?? this.blue,
      blueSoft: blueSoft ?? this.blueSoft,
      bg: bg ?? this.bg,
      bg2: bg2 ?? this.bg2,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      onBrand: onBrand ?? this.onBrand,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  BrandColors lerp(BrandColors? other, double t) {
    if (other == null) return this;
    return BrandColors(
      navy: Color.lerp(navy, other.navy, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      blueSoft: Color.lerp(blueSoft, other.blueSoft, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}
