import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/kanban/domain/entities/capacidade_do_dia.dart';
import 'package:managers/features/kanban/domain/entities/etapa.dart';

void main() {
  final dia = DateTime(2026, 10, 25);

  group('CapacidadeDoDia', () {
    test('o resumo do quadro: com máximo, sem máximo e acima do limite', () {
      expect(
        CapacidadeDoDia(
          data: dia,
          capacidade: 8,
          vagas: 1,
          ocupados: 3,
        ).textoCurto(),
        '3 de 8 hoje · 1 por vez',
      );
      expect(
        CapacidadeDoDia(
          data: dia,
          vagas: 2,
          ocupados: 3,
        ).textoCurto(hoje: false),
        '3 no dia · 2 por vez',
      );
      expect(
        CapacidadeDoDia(
          data: dia,
          capacidade: 8,
          vagas: 1,
          ocupados: 9,
        ).textoCurto(),
        '9 de 8 · 1 acima do limite',
      );
    });

    test('lotado é estar no máximo; acima do limite é ter passado dele', () {
      final cheio = CapacidadeDoDia(data: dia, capacidade: 8, ocupados: 8);
      expect(cheio.lotado, isTrue);
      expect(cheio.acimaDoLimite, isFalse);
      expect(cheio.excedente, 0);

      final passou = CapacidadeDoDia(data: dia, capacidade: 8, ocupados: 10);
      expect(passou.acimaDoLimite, isTrue);
      expect(passou.excedente, 2);

      final livre = CapacidadeDoDia(data: dia, ocupados: 50);
      expect(livre.semMaximo, isTrue);
      expect(livre.lotado, isFalse);
      expect(livre.ocupacao, '50');
    });
  });

  test('passaDoLimite é só dia_lotado e horario_ocupado', () {
    expect(passaDoLimite(const ServerFailure(code: 'dia_lotado')), isTrue);
    expect(passaDoLimite(const ServerFailure(code: 'horario_ocupado')), isTrue);
    expect(passaDoLimite(const ServerFailure(code: 'falta_em_pago')), isFalse);
    expect(passaDoLimite(const NetworkFailure()), isFalse);
  });

  test(
    'indiceDePronto: a marcada ou, sem marcação, a última; -1 sem etapas',
    () {
      expect(
        indiceDePronto(const [
          Etapa(id: 1, nome: 'Aguardando'),
          Etapa(id: 2, nome: 'Pronto', pronto: true),
          Etapa(id: 3, nome: 'Entregue'),
        ]),
        1,
      );
      expect(
        indiceDePronto(const [
          Etapa(id: 1, nome: 'Aguardando'),
          Etapa(id: 2, nome: 'Concluído'),
        ]),
        1,
      );
      expect(indiceDePronto(const []), -1);
    },
  );
}
