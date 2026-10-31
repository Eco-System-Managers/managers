import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/agenda/domain/entities/agendamento.dart';
import 'package:managers/features/agenda/domain/entities/slot.dart';
import 'package:managers/features/agenda/domain/params/agenda_params.dart';
import 'package:managers/features/agenda/domain/usecases/agenda_use_cases.dart';
import 'package:managers/features/agenda/presentation/providers/agendamento_provider.dart';
import 'package:managers/features/financeiro/domain/entities/saldo_cliente.dart';
import 'package:managers/features/financeiro/domain/usecases/financeiro_use_cases.dart';
import 'package:managers/features/financeiro/domain/entities/pagamento.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';
import 'package:managers/features/servicos/domain/params/listar_servicos_params.dart';
import 'package:managers/features/servicos/domain/usecases/listar_servicos_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockObter extends Mock implements ObterAgendamentoUseCase {}

class _MockAlterarStatus extends Mock
    implements AlterarStatusAgendamentoUseCase {}

class _MockRemarcar extends Mock implements RemarcarAgendamentoUseCase {}

class _MockCobrar extends Mock implements CobrarAgendamentoUseCase {}

class _MockListarSlots extends Mock implements ListarSlotsUseCase {}

class _MockObterSaldo extends Mock implements ObterSaldoClienteUseCase {}

class _MockListarServicos extends Mock implements ListarServicosUseCase {}

Agendamento _agendamento({
  StatusAgendamento status = StatusAgendamento.agendado,
  int? colaboradorId = 2,
}) => Agendamento(
  id: 3,
  clienteId: 7,
  clienteNome: 'Ana',
  colaboradorId: colaboradorId,
  colaboradorNome: 'Bia',
  dataHora: DateTime(2026, 10, 25, 10, 30),
  status: status,
  servicos: [
    ServicoAgendado(
      id: 11,
      servicoId: 3,
      nome: 'Corte',
      duracao: 30,
      precoCobrado: Decimal.parse('45.50'),
      desconto: Decimal.fromInt(0),
    ),
  ],
);

final _saldo = SaldoCliente(saldo: Decimal.fromInt(10), transacoes: const []);

void main() {
  late _MockObter obter;
  late _MockAlterarStatus alterarStatus;
  late _MockRemarcar remarcar;
  late _MockCobrar cobrar;
  late _MockListarSlots listarSlots;
  late _MockObterSaldo obterSaldo;
  late _MockListarServicos listarServicos;

  setUpAll(() {
    registerFallbackValue(
      const AlterarStatusParams(id: 0, status: StatusAgendamento.agendado),
    );
    registerFallbackValue(
      RemarcarParams(id: 0, dataHora: DateTime(2026), colaboradorId: null),
    );
    registerFallbackValue(CobrancaParams(id: 0, pagamentos: const []));
    registerFallbackValue(
      SlotsParams(data: DateTime(2026), servicoId: 0, colaboradorId: 0),
    );
    registerFallbackValue(const ListarServicosParams());
  });

  AgendamentoProvider montar({bool comCatalogo = false}) {
    return AgendamentoProvider(
      id: 3,
      obter: obter,
      alterarStatus: alterarStatus,
      remarcar: remarcar,
      cobrar: cobrar,
      listarSlots: listarSlots,
      obterSaldo: obterSaldo,
      listarServicos: comCatalogo ? listarServicos : null,
    );
  }

  setUp(() {
    obter = _MockObter();
    alterarStatus = _MockAlterarStatus();
    remarcar = _MockRemarcar();
    cobrar = _MockCobrar();
    listarSlots = _MockListarSlots();
    obterSaldo = _MockObterSaldo();
    listarServicos = _MockListarServicos();
    when(() => obter(3)).thenAnswer((_) async => Right(_agendamento()));
    when(() => obterSaldo(7)).thenAnswer((_) async => Right(_saldo));
  });

  test(
    'carregar traz a ficha e o saldo; saldo falhando não derruba a ficha',
    () async {
      final provider = montar();

      await provider.carregar();

      expect(provider.agendamento?.id, 3);
      expect(provider.saldo, _saldo);

      when(() => obterSaldo(7))
          .thenAnswer((_) async => const Left(ServerFailure()));
      await provider.carregar();

      expect(provider.agendamento, isNotNull);
      expect(provider.saldo, isNull);
      expect(provider.erroAoCarregar, isNull);
    },
  );

  test(
    'com o catálogo injetado, carregar traz os serviços ativos para a troca '
    'na cobrança; falhando ou sem o use case, a ficha segue sem a troca',
    () async {
      final corte = Servico(
        id: 3,
        nome: 'Corte',
        duracao: 30,
        preco: Decimal.parse('45.50'),
      );
      when(() => listarServicos(any())).thenAnswer((_) async => Right([corte]));
      final provider = montar(comCatalogo: true);

      await provider.carregar();

      expect(provider.servicosParaTrocar, [corte]);
      final params =
          verify(() => listarServicos(captureAny())).captured.single
              as ListarServicosParams;
      expect(params.ativo, isTrue);

      when(() => listarServicos(any()))
          .thenAnswer((_) async => const Left(NetworkFailure()));
      final semCatalogo = montar(comCatalogo: true);
      await semCatalogo.carregar();
      expect(semCatalogo.agendamento, isNotNull);
      expect(semCatalogo.servicosParaTrocar, isEmpty);

      final semUseCase = montar();
      await semUseCase.carregar();
      expect(semUseCase.servicosParaTrocar, isEmpty);
    },
  );

  test('erro ao carregar vira erroAoCarregar', () async {
    when(() => obter(3)).thenAnswer((_) async => const Left(NotFoundFailure()));
    final provider = montar();

    await provider.carregar();

    expect(provider.agendamento, isNull);
    expect(provider.erroAoCarregar, isA<NotFoundFailure>());
  });

  test(
    'alterarStatus guarda o que a API devolveu; cancelar fecha a ficha',
    () async {
      when(() => alterarStatus(any())).thenAnswer(
        (invocation) async => Right(
          _agendamento(
            status:
                (invocation.positionalArguments.single as AlterarStatusParams)
                    .status,
          ),
        ),
      );
      final provider = montar();
      await provider.carregar();

      await provider.alterarStatus(StatusAgendamento.confirmado);
      expect(provider.agendamento?.status, StatusAgendamento.confirmado);
      expect(provider.cancelado, isFalse);

      await provider.cancelar();
      expect(provider.cancelado, isTrue);

      final params = verify(() => alterarStatus(captureAny())).captured
          .cast<AlterarStatusParams>();
      expect(params.map((p) => p.id), [3, 3]);
      expect(params.map((p) => p.status), [
        StatusAgendamento.confirmado,
        StatusAgendamento.cancelado,
      ]);
    },
  );

  test('erro numa ação fica em errorMessage e a ficha continua', () async {
    when(() => alterarStatus(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    final provider = montar();
    await provider.carregar();

    await provider.cancelar();

    expect(provider.cancelado, isFalse);
    expect(provider.errorMessage, isNotNull);
    expect(provider.agendamento?.status, StatusAgendamento.agendado);

    provider.limparErro();
    expect(provider.errorMessage, isNull);
  });

  test('remarcar manda a nova data e o profissional atual; conflito vira '
      'mensagem', () async {
    when(() => remarcar(any())).thenAnswer((_) async => Right(_agendamento()));
    final provider = montar();
    await provider.carregar();

    await provider.remarcar(DateTime(2026, 10, 26, 9));

    final params =
        verify(() => remarcar(captureAny())).captured.single as RemarcarParams;
    expect(params.id, 3);
    expect(params.dataHora, DateTime(2026, 10, 26, 9));
    expect(params.colaboradorId, 2);
    expect(provider.errorMessage, isNull);

    when(() => remarcar(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(message: 'Conflito.', code: 'horario_conflito'),
      ),
    );
    await provider.remarcar(DateTime(2026, 10, 26, 10));
    expect(provider.errorMessage, 'Conflito.');
  });

  test('cobrar devolve true, guarda a ficha concluída e recarrega o saldo; '
      'soma inválida devolve false', () async {
    when(() => cobrar(any())).thenAnswer(
      (_) async => Right(_agendamento(status: StatusAgendamento.concluido)),
    );
    final provider = montar();
    await provider.carregar();

    final ok = await provider.cobrar(
      CobrancaParams(
        id: 3,
        pagamentos: [
          Pagamento(forma: FormaPagamento.pix, valor: Decimal.parse('45.50')),
        ],
      ),
    );

    expect(ok, isTrue);
    expect(provider.agendamento?.status, StatusAgendamento.concluido);
    verify(() => obterSaldo(7)).called(2);

    when(() => cobrar(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(message: 'A soma não bate.', code: 'soma_invalida'),
      ),
    );
    final falhou = await provider.cobrar(
      CobrancaParams(id: 3, pagamentos: const []),
    );

    expect(falhou, isFalse);
    expect(provider.errorMessage, 'A soma não bate.');
  });

  test('slotsParaRemarcar usa o serviço e o profissional do agendamento; sem '
      'profissional não há grade', () async {
    when(() => listarSlots(any())).thenAnswer(
      (_) async =>
          const Right([Slot(hora: (hora: 9, minuto: 0), disponivel: true)]),
    );
    final provider = montar();
    await provider.carregar();

    final slots = await provider.slotsParaRemarcar(DateTime(2026, 10, 26));

    expect(slots, hasLength(1));
    final params =
        verify(() => listarSlots(captureAny())).captured.single as SlotsParams;
    expect(
      (params.servicoId, params.colaboradorId, params.data),
      (3, 2, DateTime(2026, 10, 26)),
    );

    when(() => obter(3))
        .thenAnswer((_) async => Right(_agendamento(colaboradorId: null)));
    await provider.carregar();

    expect(await provider.slotsParaRemarcar(DateTime(2026, 10, 26)), isEmpty);
    verifyNever(() => listarSlots(any()));
  });
}
