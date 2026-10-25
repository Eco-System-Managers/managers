import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/agenda/domain/entities/agendamento.dart';
import 'package:managers/features/agenda/domain/usecases/agenda_use_cases.dart';
import 'package:managers/features/agenda/presentation/providers/historico_cliente_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockListar extends Mock implements ListarAgendamentosDoClienteUseCase {}

Agendamento _agendamento(
  int id,
  DateTime dataHora, {
  StatusAgendamento status = StatusAgendamento.agendado,
  List<Pagamento> pagamentos = const [],
}) => Agendamento(
  id: id,
  clienteId: 7,
  clienteNome: 'Ana',
  dataHora: dataHora,
  status: status,
  pagamentos: pagamentos,
);

void main() {
  late _MockListar listar;

  setUp(() => listar = _MockListar());

  test(
    'carregar ordena do mais recente para o mais antigo e soma o pago',
    () async {
      when(() => listar(7)).thenAnswer(
        (_) async => Right([
          _agendamento(1, DateTime(2026, 10, 1, 9)),
          _agendamento(
            2,
            DateTime(2026, 10, 20, 10),
            status: StatusAgendamento.concluido,
            pagamentos: [
              Pagamento(
                forma: FormaPagamento.pix,
                valor: Decimal.parse('45.50'),
              ),
            ],
          ),
          _agendamento(3, DateTime(2026, 10, 10, 11)),
        ]),
      );
      final provider = HistoricoClienteProvider(clienteId: 7, listar: listar);

      await provider.carregar();

      expect(provider.carregado, isTrue);
      expect(provider.agendamentos.map((a) => a.id), [2, 3, 1]);
      expect(provider.total, 3);
      expect(provider.totalPago, Decimal.parse('45.50'));
    },
  );

  test('erro fica no provider sem derrubar a ficha', () async {
    when(() => listar(7)).thenAnswer((_) async => const Left(NetworkFailure()));
    final provider = HistoricoClienteProvider(clienteId: 7, listar: listar);

    await provider.carregar();

    expect(provider.carregado, isFalse);
    expect(provider.erro, isA<NetworkFailure>());
    expect(provider.isLoading, isFalse);
  });
}
