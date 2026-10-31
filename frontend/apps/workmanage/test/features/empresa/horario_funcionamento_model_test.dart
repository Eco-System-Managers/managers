import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/empresa/data/models/horario_funcionamento_model.dart';
import 'package:managers/features/empresa/domain/entities/horario_funcionamento.dart';

void main() {
  group('HorarioFuncionamentoModel', () {
    test('fromJson lê capacidade e vagas', () {
      final model = HorarioFuncionamentoModel.fromJson({
        'id': 1,
        'dia': 0,
        'abertura': '08:00:00',
        'fechamento': '18:00:00',
        'ativo': true,
        'capacidade': 8,
        'vagas': 2,
      });

      expect(model.capacidade, 8);
      expect(model.vagas, 2);
      expect(model.toEntity().vagas, 2);
    });

    test('sem vagas na resposta vale 1, e capacidade nula é sem máximo', () {
      final model = HorarioFuncionamentoModel.fromJson({
        'dia': 5,
        'abertura': null,
        'fechamento': null,
        'ativo': false,
        'capacidade': null,
      });

      expect(model.vagas, 1);
      expect(model.capacidade, isNull);
      expect(model.toEntity().capacidade, isNull);
    });

    test('toJson manda capacidade e vagas', () {
      const model = HorarioFuncionamentoModel(
        dia: 2,
        ativo: true,
        abertura: '09:00:00',
        fechamento: '17:00:00',
        capacidade: null,
        vagas: 3,
      );

      expect(model.toJson(), {
        'dia': 2,
        'ativo': true,
        'abertura': '09:00:00',
        'fechamento': '17:00:00',
        'capacidade': null,
        'vagas': 3,
      });
    });

    test('fromEntity e toEntity vão e voltam sem perder nada', () {
      const entidade = HorarioFuncionamento(
        dia: DiaSemana.sabado,
        abertura: HoraDoDia(8, 30),
        fechamento: HoraDoDia(12, 0),
        capacidade: 14,
        vagas: 2,
      );

      final volta = HorarioFuncionamentoModel.fromEntity(entidade).toEntity();

      expect(volta.dia, DiaSemana.sabado);
      expect(volta.abertura?.emMinutos, 8 * 60 + 30);
      expect(volta.fechamento?.emMinutos, 12 * 60);
      expect(volta.capacidade, 14);
      expect(volta.vagas, 2);
    });
  });

  group('HorarioFuncionamento.copyWith', () {
    const dia = HorarioFuncionamento(
      dia: DiaSemana.segunda,
      capacidade: 8,
      vagas: 2,
    );

    test('sem argumento mantém capacidade e vagas', () {
      final copia = dia.copyWith(ativo: false);

      expect(copia.capacidade, 8);
      expect(copia.vagas, 2);
    });

    test('capacidade null vira sem máximo', () {
      expect(dia.copyWith(capacidade: null).capacidade, isNull);
      expect(dia.copyWith(capacidade: 10).capacidade, 10);
    });
  });
}
