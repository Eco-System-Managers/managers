import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/theme/theme.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/grade_de_horarios.dart';

// horários de larguras diferentes no texto: o 1 é mais estreito que o 8
const _horas = <Hora>[
  (hora: 8, minuto: 45),
  (hora: 11, minuto: 0),
  (hora: 11, minuto: 15),
  (hora: 11, minuto: 30),
  (hora: 8, minuto: 0),
  (hora: 10, minuto: 0),
];

// 320 de largura: quatro colunas de 74 com os vãos de 8
Future<List<Hora?>> _montar(
  WidgetTester tester, {
  bool comSemHora = false,
}) async {
  final escolhidas = <Hora?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: GradeDeHorarios(
              horas: _horas,
              selecionada: (hora: 11, minuto: 0),
              onSelecionar: escolhidas.add,
              // as 10:00 estão ocupadas
              disponivel: (h) => h != (hora: 10, minuto: 0),
              semHora: comSemHora ? 'Sem hora marcada' : null,
              onSemHora: () => escolhidas.add(null),
            ),
          ),
        ),
      ),
    ),
  );
  return escolhidas;
}

Rect _celula(WidgetTester tester, String texto) => tester.getRect(
  find.ancestor(of: find.text(texto), matching: find.byType(SizedBox)).first,
);

void main() {
  testWidgets('toda célula tem o mesmo tamanho, seja qual for o horário', (
    tester,
  ) async {
    await _montar(tester);

    final tamanhos = {
      for (final h in _horas) _celula(tester, formatarHora(h)).size,
    };

    expect(tamanhos, hasLength(1));
  });

  testWidgets('as células ficam em colunas: a da linha de baixo começa '
      'embaixo da de cima, sem passar da linha', (tester) async {
    await _montar(tester);

    final primeira = _celula(tester, '08:45');
    final quarta = _celula(tester, '11:30');
    final quinta = _celula(tester, '08:00');

    expect(quarta.top, primeira.top);
    expect(quinta.top, greaterThan(primeira.top));
    expect(quinta.left, primeira.left);
    expect(quarta.right, lessThanOrEqualTo(primeira.left + 320));
  });

  testWidgets('tocar numa livre escolhe; a ocupada não responde', (
    tester,
  ) async {
    final escolhidas = await _montar(tester);

    await tester.tap(find.text('08:45'));
    await tester.tap(find.text('10:00'));

    expect(escolhidas, [(hora: 8, minuto: 45)]);
  });

  testWidgets('com semHora, a primeira célula ocupa a linha e escolhe sem '
      'hora; as horas vêm embaixo, em colunas', (tester) async {
    final escolhidas = await _montar(tester, comSemHora: true);

    final semHora = _celula(tester, 'Sem hora marcada');
    final primeira = _celula(tester, '08:45');

    expect(semHora.width, 320);
    expect(primeira.top, greaterThan(semHora.top));
    expect(primeira.left, semHora.left);

    await tester.tap(find.text('Sem hora marcada'));
    expect(escolhidas, [null]);
  });
}
