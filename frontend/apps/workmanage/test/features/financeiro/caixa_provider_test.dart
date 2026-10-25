import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/financeiro/domain/entities/caixa.dart';
import 'package:managers/features/financeiro/domain/usecases/financeiro_use_cases.dart';
import 'package:managers/features/financeiro/presentation/providers/caixa_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockObterCaixa extends Mock implements ObterCaixaUseCase {}

final _hoje = DateTime(2026, 10, 25);

final _caixa = Caixa(
  total: Decimal.fromInt(150),
  ticketMedio: Decimal.fromInt(75),
  atendimentos: 2,
  porForma: const [],
  pagamentos: const [],
);

void main() {
  late _MockObterCaixa obterCaixa;

  setUpAll(() => registerFallbackValue(const CaixaParams()));

  CaixaProvider montar() => CaixaProvider(obterCaixa: obterCaixa, hoje: _hoje);

  // o período da última chamada
  (DateTime?, DateTime?) ultimoPeriodo() {
    final params =
        verify(() => obterCaixa(captureAny())).captured.last as CaixaParams;
    return (params.inicio, params.fim);
  }

  setUp(() {
    obterCaixa = _MockObterCaixa();
    when(() => obterCaixa(any())).thenAnswer((_) async => Right(_caixa));
  });

  test('começa em hoje e carrega o período', () async {
    final provider = montar();
    expect(provider.periodo, PeriodoCaixa.hoje);

    await provider.carregar();

    expect(provider.carregado, isTrue);
    expect(provider.caixa, _caixa);
    expect(ultimoPeriodo(), (_hoje, _hoje));
  });

  test('os atalhos calculam o período e recarregam', () async {
    final provider = montar();

    await provider.selecionarPeriodo(PeriodoCaixa.semana);
    expect(ultimoPeriodo(), (DateTime(2026, 10, 19), _hoje));

    await provider.selecionarPeriodo(PeriodoCaixa.mes);
    expect(ultimoPeriodo(), (DateTime(2026, 10), _hoje));

    await provider.selecionarPeriodo(PeriodoCaixa.hoje);
    expect(ultimoPeriodo(), (_hoje, _hoje));
    expect(provider.periodo, PeriodoCaixa.hoje);
  });

  test('selecionarIntervalo vira período personalizado, sem a hora', () async {
    final provider = montar();

    await provider.selecionarIntervalo(
      DateTime(2026, 9, 1, 8),
      DateTime(2026, 9, 30, 20),
    );

    expect(provider.periodo, PeriodoCaixa.personalizado);
    expect(provider.inicio, DateTime(2026, 9, 1));
    expect(provider.fim, DateTime(2026, 9, 30));
    expect(ultimoPeriodo(), (DateTime(2026, 9, 1), DateTime(2026, 9, 30)));
  });

  test('erro vira erroAoCarregar', () async {
    when(() => obterCaixa(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isFalse);
    expect(provider.erroAoCarregar, isA<NetworkFailure>());
  });
}
