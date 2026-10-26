import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/widgets/faixa_semana.dart';

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
}
