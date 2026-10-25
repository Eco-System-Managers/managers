import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/utils/datas.dart';

void main() {
  test('data vai e volta no formato da API', () {
    final data = dataDaApi('2026-10-19');
    expect((data.year, data.month, data.day), (2026, 10, 19));
    expect(dataParaApi(data), '2026-10-19');
    expect(formatarData(data), '19/10/2026');
  });

  test('data e hora da API chegam em horário local', () {
    final dataHora = dataHoraDaApi('2026-10-19T10:30:00-03:00');
    expect(dataHora.isUtc, isFalse);
    expect(dataHora.toUtc(), DateTime.utc(2026, 10, 19, 13, 30));
  });

  test('data e hora para a API levam o fuso, que o Dart omite', () {
    final local = DateTime(2026, 10, 19, 10, 30);
    final texto = dataHoraParaApi(local);
    expect(texto, startsWith('2026-10-19T10:30:00'));
    expect(texto, matches(RegExp(r'[+-]\d{2}:\d{2}$')));
    // a API lê de volta o mesmo instante
    expect(DateTime.parse(texto).toLocal(), local);
  });

  test('hora aceita os dois formatos da API', () {
    expect(horaDaApi('10:30'), (hora: 10, minuto: 30));
    expect(horaDaApi('08:05:00'), (hora: 8, minuto: 5));
    expect(horaParaApi((hora: 8, minuto: 5)), '08:05');
    expect(formatarHora((hora: 18, minuto: 0)), '18:00');
  });

  test('formatarDataHora junta os dois', () {
    expect(formatarDataHora(DateTime(2026, 10, 19, 9, 5)), '19/10/2026 09:05');
  });
}
