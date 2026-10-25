import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/dashboard/domain/entities/dashboard_resumo.dart';
import 'package:managers/features/dashboard/domain/usecases/obter_resumo_use_case.dart';
import 'package:managers/features/dashboard/presentation/providers/resumo_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockObterResumo extends Mock implements ObterResumoUseCase {}

final _resumo = DashboardResumo(
  isKanban: false,
  faturamentoMes: Decimal.fromInt(1500),
  faturamentoVariacao: null,
  atendimentosMes: 20,
  atendimentosVariacao: 12,
  ticketMedio: Decimal.fromInt(75),
  clientesNovosMes: 3,
  clientesNovosVariacao: null,
  rankingServicos: const [],
  agendamentosHoje: const [],
);

void main() {
  late _MockObterResumo obterResumo;

  setUpAll(() => registerFallbackValue(NoParams()));

  setUp(() => obterResumo = _MockObterResumo());

  test('carregar guarda o resumo', () async {
    when(() => obterResumo(any())).thenAnswer((_) async => Right(_resumo));
    final provider = ResumoProvider(obterResumo: obterResumo);

    await provider.carregar();

    expect(provider.carregado, isTrue);
    expect(provider.resumo, _resumo);
    expect(provider.isLoading, isFalse);
  });

  test('erro vira erroAoCarregar', () async {
    when(() => obterResumo(any()))
        .thenAnswer((_) async => const Left(ServerFailure()));
    final provider = ResumoProvider(obterResumo: obterResumo);

    await provider.carregar();

    expect(provider.carregado, isFalse);
    expect(provider.erroAoCarregar, isA<ServerFailure>());
  });
}
