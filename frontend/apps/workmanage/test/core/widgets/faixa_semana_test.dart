import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/theme/theme.dart';
import 'package:managers/core/widgets/faixa_semana.dart';

// a faixa com o estado de quem usa: o dia escolhido e se o mês está aberto
Future<List<DateTime>> _montar(
  WidgetTester tester, {
  required bool expandido,
}) async {
  final escolhidos = <DateTime>[];
  var dia = DateTime(2026, 10, 30);
  var aberto = expandido;
  late StateSetter redesenhar;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            redesenhar = setState;
            return FaixaSemana(
              dia: dia,
              hoje: DateTime(2026, 10, 30),
              temRegistro: (_) => false,
              expandido: aberto,
              onSelecionar: (d) {
                escolhidos.add(d);
                setState(() => dia = d);
              },
            );
          },
        ),
      ),
    ),
  );
  // troca de vista, como o título ou a alça fazem
  redesenhar(() => aberto = !aberto);
  await tester.pumpAndSettle();
  return escolhidos;
}

void main() {
  test('diasDaSemana vai de segunda a domingo em volta do dia', () {
    final dias = FaixaSemana.diasDaSemana(DateTime(2026, 10, 29));
    expect(dias.first, DateTime(2026, 10, 26));
    expect(dias.last, DateTime(2026, 11, 1));
    expect(dias.length, 7);
  });

  test('diasDoMes são seis semanas começando na segunda antes do dia 1', () {
    final dias = FaixaSemana.diasDoMes(DateTime(2026, 10, 15));
    expect(dias.length, 42);
    expect(dias.first, DateTime(2026, 9, 28));
    expect(dias.first.weekday, DateTime.monday);
    expect(dias.contains(DateTime(2026, 10, 1)), isTrue);
    expect(dias.contains(DateTime(2026, 10, 31)), isTrue);
  });

  // sem key, o PageView novo herdava os pixels do outro: a semana virava
  // agosto de 2116 e o mês virava fevereiro de 2006
  testWidgets('semana para mês: deslizar vai ao mês seguinte', (tester) async {
    final escolhidos = await _montar(tester, expandido: false);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(escolhidos, [DateTime(2026, 11, 30)]);
  });

  testWidgets('mês para semana: deslizar vai à semana seguinte', (
    tester,
  ) async {
    final escolhidos = await _montar(tester, expandido: true);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(escolhidos, [DateTime(2026, 11, 6)]);
  });

  testWidgets('o chevron aponta para baixo com a semana e para cima com o '
      'mês, e tocar nele abre e fecha', (tester) async {
    var aberto = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => FaixaSemana(
              dia: DateTime(2026, 10, 30),
              hoje: DateTime(2026, 10, 30),
              temRegistro: (_) => false,
              expandido: aberto,
              onSelecionar: (_) {},
              onExpandir: (v) => setState(() => aberto = v),
            ),
          ),
        ),
      ),
    );

    double giro() =>
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns;

    expect(find.bySemanticsLabel('Abrir o mês'), findsOneWidget);
    expect(giro(), 0);

    await tester.tap(find.bySemanticsLabel('Abrir o mês'));
    await tester.pumpAndSettle();

    expect(aberto, isTrue);
    expect(find.bySemanticsLabel('Fechar o mês'), findsOneWidget);
    expect(giro(), 0.5);

    await tester.tap(find.bySemanticsLabel('Fechar o mês'));
    await tester.pumpAndSettle();

    expect(aberto, isFalse);
    expect(giro(), 0);
  });
}
