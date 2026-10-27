import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/dashboard/domain/entities/dashboard_resumo.dart';
import 'package:managers/features/dashboard/domain/proximo_de_hoje.dart';

AgendamentoHoje _as(int id, String hora) => AgendamentoHoje(
  id: id,
  clienteNome: 'C$id',
  servicoNome: 'Corte',
  hora: hora,
  status: 'agendado',
);

void main() {
  final hoje = [_as(1, '09:00'), _as(2, '10:30'), _as(3, '14:00')];

  test('o próximo é o primeiro cuja hora ainda não passou', () {
    expect(proximoDeHoje(hoje, minutosAgora: 8 * 60)?.id, 1);
    // 9:00 em ponto ainda é o das 9
    expect(proximoDeHoje(hoje, minutosAgora: 9 * 60)?.id, 1);
    // 9:01: passou, o próximo é o das 10:30
    expect(proximoDeHoje(hoje, minutosAgora: 9 * 60 + 1)?.id, 2);
    expect(proximoDeHoje(hoje, minutosAgora: 15 * 60)?.id, isNull);
    expect(proximoDeHoje(const [], minutosAgora: 0), isNull);
  });

  test(
    'a lista fora de ordem não muda o resultado; na esteira é o primeiro',
    () {
      final bagunca = [_as(3, '14:00'), _as(1, '09:00')];
      expect(proximoDeHoje(bagunca, minutosAgora: 8 * 60)?.id, 1);
      expect(
        proximoDeHoje(bagunca, minutosAgora: 8 * 60, isKanban: true)?.id,
        3,
      );
    },
  );
}
