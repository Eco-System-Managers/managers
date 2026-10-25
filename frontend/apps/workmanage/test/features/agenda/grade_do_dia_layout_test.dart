import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/agenda/domain/entities/agendamento.dart';
import 'package:managers/features/agenda/presentation/widgets/grade_do_dia_layout.dart';
import 'package:managers/features/empresa/domain/entities/horario_funcionamento.dart';

Agendamento _agendamento(int id, int hora, int minuto, {int duracao = 30}) =>
    Agendamento(
      id: id,
      clienteId: 7,
      clienteNome: 'Ana',
      dataHora: DateTime(2026, 10, 25, hora, minuto),
      servicos: [
        if (duracao > 0)
          ServicoAgendado(
            id: id,
            servicoId: 1,
            nome: 'Corte',
            duracao: duracao,
            precoCobrado: Decimal.fromInt(40),
            desconto: Decimal.fromInt(0),
          ),
      ],
    );

const _expediente = (abertura: HoraDoDia(9, 0), fechamento: HoraDoDia(18, 0));

void main() {
  group('distribuirColunas', () {
    test('sem sobreposição, cada um ocupa a largura inteira', () {
      final blocos = distribuirColunas([
        _agendamento(1, 9, 0),
        _agendamento(2, 9, 30),
        _agendamento(3, 11, 0),
      ]);

      expect(blocos.map((b) => b.coluna), [0, 0, 0]);
      expect(blocos.map((b) => b.colunas), [1, 1, 1]);
      expect(blocos.first.inicio, 9 * 60);
      expect(blocos.first.fim, 9 * 60 + 30);
    });

    test(
      'quem se sobrepõe divide a largura; o grupo seguinte volta a inteira',
      () {
        final blocos = distribuirColunas([
          _agendamento(1, 10, 0, duracao: 60),
          _agendamento(2, 10, 15),
          _agendamento(3, 10, 30),
          // 10:45 cabe na coluna do 2, que acabou às 10:45
          _agendamento(4, 10, 45),
          _agendamento(5, 14, 0),
        ]);

        final porId = {for (final b in blocos) b.agendamento.id: b};
        expect(porId[1]!.coluna, 0);
        expect(porId[2]!.coluna, 1);
        expect(porId[3]!.coluna, 2);
        expect(porId[4]!.coluna, 1);
        expect([1, 2, 3, 4].map((id) => porId[id]!.colunas), everyElement(3));
        expect(porId[5]!.colunas, 1);
      },
    );

    test('sem serviço o bloco ganha a duração mínima', () {
      final bloco = distribuirColunas([_agendamento(1, 9, 0, duracao: 0)])
          .single;
      expect(bloco.fim - bloco.inicio, duracaoMinimaDoBloco);
    });
  });

  group('intervaloDaGrade', () {
    test('é o expediente em horas cheias', () {
      final i = intervaloDaGrade(expediente: _expediente, blocos: const []);
      expect(i, (inicio: 9 * 60, fim: 18 * 60));
    });

    test('estica para caber agendamento fora do expediente', () {
      final blocos = distribuirColunas([
        _agendamento(1, 7, 30),
        _agendamento(2, 18, 30, duracao: 45),
      ]);
      final i = intervaloDaGrade(expediente: _expediente, blocos: blocos);
      expect(i, (inicio: 7 * 60, fim: 20 * 60));
    });

    test('dia fechado: só o que está marcado; nada marcado, nada de grade', () {
      expect(intervaloDaGrade(expediente: null, blocos: const []), isNull);
      final blocos = distribuirColunas([_agendamento(1, 10, 15)]);
      expect(intervaloDaGrade(expediente: null, blocos: blocos), (
        inicio: 10 * 60,
        fim: 11 * 60,
      ));
    });

    test('expediente de meia hora ainda ganha uma hora de grade', () {
      final i = intervaloDaGrade(
        expediente: (abertura: HoraDoDia(9, 0), fechamento: HoraDoDia(9, 30)),
        blocos: const [],
      );
      expect(i, (inicio: 9 * 60, fim: 10 * 60));
    });
  });

  test('minutoTocado prende à linha de baixo do passo', () {
    expect(
      minutoTocado(inicioDaGrade: 9 * 60, minutosDesdeOTopo: 0, passo: 30),
      9 * 60,
    );
    expect(
      minutoTocado(inicioDaGrade: 9 * 60, minutosDesdeOTopo: 29, passo: 30),
      9 * 60,
    );
    expect(
      minutoTocado(inicioDaGrade: 9 * 60, minutosDesdeOTopo: 31, passo: 30),
      9 * 60 + 30,
    );
    expect(
      minutoTocado(inicioDaGrade: 9 * 60, minutosDesdeOTopo: 50, passo: 20),
      9 * 60 + 40,
    );
  });
}
