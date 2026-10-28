import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/agenda/domain/usecases/agenda_use_cases.dart';
import 'package:managers/features/dashboard/domain/entities/dashboard_resumo.dart';
import 'package:managers/features/dashboard/domain/usecases/obter_resumo_use_case.dart';
import 'package:managers/features/dashboard/presentation/providers/resumo_provider.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/listar_colaboradores_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockObterResumo extends Mock implements ObterResumoUseCase {}

class _MockListarPendencias extends Mock implements ListarPendenciasUseCase {}

class _MockListarColaboradores extends Mock
    implements ListarColaboradoresUseCase {}

const _bia = Colaborador(id: 2, nome: 'Bia', email: 'bia@demo.com');
const _inativo = Colaborador(
  id: 3,
  nome: 'Caio',
  email: 'caio@demo.com',
  ativo: false,
);

final _hoje = DateTime(2026, 10, 25);

final _resumo = DashboardResumo(
  isKanban: false,
  intervalo: IntervaloResumo(
    inicio: _hoje,
    fim: _hoje,
    anteriorInicio: DateTime(2026, 10, 24),
    anteriorFim: DateTime(2026, 10, 24),
  ),
  colaboradorId: null,
  faturamento: Decimal.fromInt(1500),
  faturamentoVariacao: null,
  atendimentos: 20,
  atendimentosVariacao: 12,
  ticketMedio: Decimal.fromInt(75),
  clientesNovos: 3,
  clientesNovosVariacao: null,
  rankingServicos: const [],
  agendamentosHoje: const [],
);

void main() {
  late _MockObterResumo obterResumo;
  late _MockListarColaboradores listarColaboradores;
  late _MockListarPendencias listarPendencias;

  setUpAll(() {
    registerFallbackValue(const ResumoParams());
    registerFallbackValue(NoParams());
  });

  ResumoProvider montar({bool filtraPorProfissional = true}) => ResumoProvider(
    obterResumo: obterResumo,
    listarColaboradores: listarColaboradores,
    listarPendencias: listarPendencias,
    filtraPorProfissional: filtraPorProfissional,
    hoje: _hoje,
  );

  // os parâmetros da última chamada
  ResumoParams ultimosParams() =>
      verify(() => obterResumo(captureAny())).captured.last as ResumoParams;

  setUp(() {
    obterResumo = _MockObterResumo();
    listarColaboradores = _MockListarColaboradores();
    listarPendencias = _MockListarPendencias();
    when(() => listarPendencias(any()))
        .thenAnswer((_) async => const Right([]));
    when(() => listarColaboradores(any()))
        .thenAnswer((_) async => const Right([_bia, _inativo]));
    when(() => obterResumo(any())).thenAnswer((_) async => Right(_resumo));
  });

  test('começa em hoje e carrega o período', () async {
    final provider = montar();
    expect(provider.atalho, AtalhoPeriodo.hoje);

    await provider.carregar();

    expect(provider.carregado, isTrue);
    expect(provider.resumo, _resumo);
    final params = ultimosParams();
    expect((params.inicio, params.fim), (_hoje, _hoje));
    expect(params.colaboradorId, isNull);
  });

  test('os atalhos calculam o período e recarregam', () async {
    final provider = montar();

    await provider.selecionarAtalho(AtalhoPeriodo.semana);
    var params = ultimosParams();
    expect((params.inicio, params.fim), (DateTime(2026, 10, 19), _hoje));

    await provider.selecionarAtalho(AtalhoPeriodo.mes);
    params = ultimosParams();
    expect((params.inicio, params.fim), (DateTime(2026, 10), _hoje));

    await provider.selecionarAtalho(AtalhoPeriodo.hoje);
    params = ultimosParams();
    expect((params.inicio, params.fim), (_hoje, _hoje));
  });

  test('selecionarIntervalo vira período personalizado, sem a hora', () async {
    final provider = montar();

    await provider.selecionarIntervalo(
      DateTime(2026, 9, 1, 8),
      DateTime(2026, 9, 30, 20),
    );

    expect(provider.atalho, AtalhoPeriodo.personalizado);
    expect(provider.inicio, DateTime(2026, 9, 1));
    expect(provider.fim, DateTime(2026, 9, 30));
  });

  test(
    'o proprietário filtra por profissional; a equipe recarrega junto',
    () async {
      final provider = montar();
      await provider.carregar();
      expect(provider.colaboradores, [_bia]);

      await provider.filtrarColaborador(2);

      expect(ultimosParams().colaboradorId, 2);
      expect(provider.colaboradorId, 2);
      // a equipe vem de novo a cada carga: quem entrou depois aparece no filtro
      verify(() => listarColaboradores(any())).called(2);

      await provider.filtrarColaborador(null);
      expect(ultimosParams().colaboradorId, isNull);
    },
  );

  test(
    'quem não é proprietário não carrega a equipe: a API já trava',
    () async {
      final provider = montar(filtraPorProfissional: false);

      await provider.carregar();

      expect(provider.colaboradores, isEmpty);
      verifyNever(() => listarColaboradores(any()));
    },
  );

  test('erro vira erroAoCarregar', () async {
    when(() => obterResumo(any()))
        .thenAnswer((_) async => const Left(ServerFailure()));
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isFalse);
    expect(provider.erroAoCarregar, isA<ServerFailure>());
  });
}
