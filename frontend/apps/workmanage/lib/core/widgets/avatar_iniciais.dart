import 'package:flutter/material.dart';

import '../theme/brand.dart';

// o avatar de uma pessoa: a foto, quando existe, ou as iniciais do nome
class AvatarIniciais extends StatelessWidget {
  const AvatarIniciais({
    super.key,
    required this.nome,
    this.fotoUrl = '',
    this.raio = 20,
  });

  final String nome;
  final String fotoUrl;
  final double raio;

  // "Ana Silva" -> "AS"; "Ana" -> "A"; "" -> "?"
  static String iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (partes.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return '$primeira$ultima'.toUpperCase();
  }

  // o estilo do Design System mais próximo de 0,8 × raio (no empate, o
  // menor): o raio padrão (20) dá o body-strong; o da ficha (40), o h1
  static TextStyle estiloDaInicial(double raio) {
    final alvo = raio * 0.8;
    const escala = [
      BrandText.caption,
      BrandText.label,
      BrandText.bodyStrong,
      BrandText.h3,
      BrandText.h2,
      BrandText.h1,
    ];
    var melhor = escala.first;
    for (final estilo in escala) {
      if ((estilo.fontSize! - alvo).abs() < (melhor.fontSize! - alvo).abs()) {
        melhor = estilo;
      }
    }
    return melhor;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return CircleAvatar(
      radius: raio,
      backgroundColor: colors.primaryContainer,
      foregroundImage: fotoUrl.isNotEmpty ? NetworkImage(fotoUrl) : null,
      child: Text(
        iniciais(nome),
        style: estiloDaInicial(raio).copyWith(
          fontWeight: FontWeight.w600,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }
}
