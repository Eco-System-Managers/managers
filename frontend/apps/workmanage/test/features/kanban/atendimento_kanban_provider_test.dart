import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/clientes/domain/entities/objeto_cliente.dart';
import 'package:managers/features/financeiro/domain/entities/pagamento.dart';
import 'package:managers/features/financeiro/domain/entities/saldo_cliente.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';
import 'package:managers/features/financeiro/domain/usecases/financeiro_use_cases.dart';
import 'package:managers/features/kanban/domain/entities/atendimento_kanban.dart';
import 'package:managers/features/kanban/domain/entities/etapa.dart';
import 'package:managers/features/kanban/domain/params/kanban_params.dart';
import 'package:managers/features/kanban/domain/usecases/kanban_use_cases.dart';
import 'package:managers/features/kanban/presentation/providers/atendimento_kanban_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockObter extends Mock implements ObterAtendimentoKanbanUseCase {}

class _MockListarEtapas extends Mock implements ListarEtapasUseCase {}

class _MockMover extends Mock implements MoverAtendimentoUseCase {}

class _MockCobrar extends Mock implements CobrarAtendimentoKanbanUseCase {}

class _MockDesfazerCobranca extends Mock implements DesfazerCobrancaUseCase {}

class _MockAlterarFalta extends Mock implements AlterarFaltaUseCase {}

class _MockRemover extends Mock implements RemoverAtendimentoKanbanUseCase {}

class _MockObterSaldo extends Mock implements ObterSaldoClienteUseCase {}

const _uno = Veiculo(
  id: 10,
  clienteId: 7,
  placa: 'ABC1D23',
  marca: 'Fiat',
  modelo: 'Uno',
  cor: 'Prata',
);

AtendimentoKanban _card({
  int etapaId = 1,
  bool pago = false,
  bool faltou = false,
}) => AtendimentoKanban(
  id: 3,
  etapaId: etapaId,
  etapaNome: 'Aguardando',
  objeto: const ObjetoCliente.veiculo(_uno),
  clienteNome: 'Ana',
  servicoId: 3,
  servicoNome: 'Lavagem',
  servicoPreco: Decimal.fromInt(60),
  pago: pago,
  faltou: faltou,
);

final _saldo = SaldoCliente(saldo: Decimal.fromInt(5), transacoes: const []);

void main() {
  late _MockObter obter;
  late _MockListarEtapas listarEtapas;
  late _MockMover mover;
  late _MockCobrar cobrar;
  late _MockDesfazerCobranca desfazerCobranca;
  late _MockAlterarFalta alterarFalta;
  late _MockRemover remover;
  late _MockObterSaldo obterSaldo;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(const MoverAtendimentoParams(id: 0, etapaId: 0));
    registerFallbackValue(CobrancaParams(id: 0, pagamentos: const []));
    registerFallbackValue(const AlterarFaltaParams(id: 0, faltou: true));
  });

  AtendimentoKanbanProvider montar() => AtendimentoKanbanProvider(
    id: 3,
    obter: obter,
    listarEtapas: listarEtapas,
    mover: mover,
    cobrar: cobrar,
    desfazerCobranca: desfazerCobranca,
    alterarFalta: alterarFalta,
    remover: remover,
    obterSaldo: obterSaldo,
  );

  setUp(() {
    obter = _MockObter();
    listarEtapas = _MockListarEtapas();
    mover = _MockMover();
    cobrar = _MockCobrar();
    desfazerCobranca = _MockDesfazerCobranca();
    alterarFalta = _MockAlterarFalta();
    remover = _MockRemover();
    obterSaldo = _MockObterSaldo();
    when(() => obter(3)).thenAnswer((_) async => Right(_card()));
    when(() => listarEtapas(any())).thenAnswer(
      (_) async => const Right([
        Etapa(id: 1, nome: 'Aguardando'),
        Etapa(id: 2, nome: 'Lavando', ordem: 1),
      ]),
    );
    when(() => obterSaldo(7)).thenAnswer((_) async => Right(_saldo));
  });

  test('carregar traz o card, as etapas e o saldo do cliente', () async {
    final provider = montar();

    await provider.carregar();

    expect(provider.atendimento?.id, 3);
    expect(provider.etapas, hasLength(2));
    expect(provider.saldo, _saldo);
  });

  test(
    'mover e alterarFalta mandam os parâmetros e guardam a resposta',
    () async {
      when(() => mover(any()))
          .thenAnswer((_) async => Right(_card(etapaId: 2)));
      when(() => alterarFalta(any()))
          .thenAnswer((_) async => Right(_card(faltou: true)));
      final provider = montar();
      await provider.carregar();

      await provider.mover(2);
      expect(provider.atendimento?.etapaId, 2);
      final mov =
          verify(() => mover(captureAny())).captured.single
              as MoverAtendimentoParams;
      expect((mov.id, mov.etapaId), (3, 2));

      await provider.alterarFalta(true);
      expect(provider.atendimento?.faltou, isTrue);
      final falta =
          verify(() => alterarFalta(captureAny())).captured.single
              as AlterarFaltaParams;
      expect((falta.id, falta.faltou), (3, true));
    },
  );

  test('falta em atendimento pago vira mensagem e a ficha continua', () async {
    when(() => alterarFalta(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'Esse atendimento já foi cobrado.',
          code: 'falta_em_pago',
        ),
      ),
    );
    final provider = montar();
    await provider.carregar();

    await provider.alterarFalta(true);

    expect(provider.errorMessage, contains('já foi cobrado'));
    expect(provider.atendimento?.faltou, isFalse);
  });

  test('cobrar devolve true e recarrega o saldo; desfazer também', () async {
    when(() => cobrar(any())).thenAnswer((_) async => Right(_card(pago: true)));
    when(() => desfazerCobranca(3)).thenAnswer((_) async => Right(_card()));
    final provider = montar();
    await provider.carregar();

    final ok = await provider.cobrar(
      CobrancaParams(
        id: 3,
        pagamentos: [
          Pagamento(forma: FormaPagamento.pix, valor: Decimal.fromInt(60)),
        ],
      ),
    );

    expect(ok, isTrue);
    expect(provider.atendimento?.pago, isTrue);
    verify(() => obterSaldo(7)).called(2);

    await provider.desfazerCobranca();
    expect(provider.atendimento?.pago, isFalse);
    verify(() => obterSaldo(7)).called(1);
  });

  test('remover fecha a ficha', () async {
    when(() => remover(3)).thenAnswer((_) async => const Right(null));
    final provider = montar();
    await provider.carregar();

    await provider.remover();

    expect(provider.removido, isTrue);
  });
}
