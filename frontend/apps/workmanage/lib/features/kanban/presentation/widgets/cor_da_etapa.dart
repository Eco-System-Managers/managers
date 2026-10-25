import 'package:flutter/material.dart';

// a cor de uma etapa vem da API como "#F59E0B"; sem cor (ou cor inválida),
// a cor primária do tema
Color corDaEtapa(String hex, ColorScheme colors) {
  final limpo = hex.replaceFirst('#', '');
  if (limpo.length != 6) return colors.primary;
  final valor = int.tryParse(limpo, radix: 16);
  if (valor == null) return colors.primary;
  return Color(0xFF000000 | valor);
}

// a paleta oferecida ao criar ou editar uma etapa (as três padrão vêm da API
// com as três primeiras)
const coresDeEtapa = [
  '#F59E0B',
  '#3B82F6',
  '#10B981',
  '#EF4444',
  '#8B5CF6',
  '#EC4899',
  '#14B8A6',
  '#6B7280',
];
