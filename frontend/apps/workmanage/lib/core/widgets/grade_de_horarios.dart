import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/brand.dart';
import '../utils/datas.dart';

// as horas de um dia para escolher, na agenda e na esteira, em colunas
// iguais: quantas células de largura mínima couberem na linha, todas
// esticadas na mesma largura, com algarismos de largura fixa. assim "11:00"
// e "08:45" ficam do mesmo tamanho e uma embaixo da outra. a escolhida é o
// azul da marca com texto branco, a livre é neutra com borda e a ocupada
// fica apagada no fundo 2. com semHora, a primeira célula ocupa a linha
// inteira e vale como "sem hora marcada" (escolhida quando não há hora)
class GradeDeHorarios extends StatelessWidget {
  const GradeDeHorarios({
    super.key,
    required this.horas,
    required this.selecionada,
    required this.onSelecionar,
    this.disponivel,
    this.semHora,
    this.onSemHora,
  });

  final List<Hora> horas;
  final Hora? selecionada;
  final ValueChanged<Hora> onSelecionar;

  // null: todas livres
  final bool Function(Hora hora)? disponivel;

  final String? semHora;
  final VoidCallback? onSemHora;

  // a célula não fica mais estreita que isso: "00:00" com folga dos lados
  static const _larguraMinima = 72.0;
  static const _altura = 40.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricoes) {
        const vao = BrandSpacing.space2;
        final linha = restricoes.maxWidth;
        final colunas = max(
          1,
          ((linha + vao) / (_larguraMinima + vao)).floor(),
        );
        // arredondada para baixo: a soma das larguras com os vãos não pode
        // passar da linha, senão a última célula desce
        final largura = ((linha - vao * (colunas - 1)) / colunas)
            .floorToDouble();

        return Wrap(
          spacing: vao,
          runSpacing: vao,
          children: [
            if (semHora != null)
              SizedBox(
                width: linha,
                height: _altura,
                child: _Celula(
                  texto: semHora!,
                  selecionada: selecionada == null,
                  livre: true,
                  onTap: onSemHora,
                ),
              ),
            for (final hora in horas)
              SizedBox(
                width: largura,
                height: _altura,
                child: _Celula(
                  texto: formatarHora(hora),
                  selecionada: hora == selecionada,
                  livre: disponivel?.call(hora) ?? true,
                  onTap: () => onSelecionar(hora),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Celula extends StatelessWidget {
  const _Celula({
    required this.texto,
    required this.selecionada,
    required this.livre,
    required this.onTap,
  });

  final String texto;
  final bool selecionada;
  final bool livre;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final corDoTexto = selecionada
        ? cores.onBrand
        : livre
        ? cores.ink
        : cores.inkMuted;
    final forma = RoundedRectangleBorder(
      borderRadius: BrandRadius.smAll,
      side: BorderSide(
        color: selecionada ? BrandColors.brandBlue : cores.border,
      ),
    );

    return Semantics(
      container: true,
      button: true,
      selected: selecionada,
      enabled: livre,
      child: Material(
        color: selecionada
            ? BrandColors.brandBlue
            : livre
            ? Colors.transparent
            : cores.bg2,
        shape: forma,
        child: InkWell(
          customBorder: forma,
          onTap: livre ? onTap : null,
          child: Center(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: corDoTexto,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
