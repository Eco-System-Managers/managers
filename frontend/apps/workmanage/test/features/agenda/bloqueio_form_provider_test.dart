import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/agenda/domain/entities/bloqueio.dart';
import 'package:managers/features/agenda/domain/params/agenda_params.dart';
import 'package:managers/features/agenda/domain/usecases/agenda_use_cases.dart';
import 'package:managers/features/agenda/presentation/providers/bloqueio_form_provider.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/listar_colaboradores_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockListarColaboradores extends Mock
    implements ListarColaboradoresUseCase {}

class _MockCriarBloqueio extends Mock implements CriarBloqueioUseCase {}

final _hoje = DateTime(2026, 11, 10);

const _bia = Colaborador(id: 2, nome: 'Bia', email: 'bia@demo.com');
const _leo = Colaborador(id: 3, nome: 'Léo', email: 'leo@demo.com');
const _inativo = Colaborador(
  id: 4,
  nome: 'Caio',
  email: 'caio@demo.com',
  ativo: false,
);

final _criado = Bloqueio(
  id: 9,
  colaboradorId: 2,
  colaboradorNome: 'Bia',
  dataInicio: _hoje,
);

void main() {
  late _MockListarColaboradores listarColaboradores;
  late _MockCriarBloqueio criar;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(
      NovoBloqueioParams(colaboradorId: 0, dataInicio: _hoje),
    );
  });

  setUp(() {
    listarColaboradores = _MockListarColaboradores();
    criar = _MockCriarBloqueio();
    when(() => listarColaboradores(any()))
        .thenAnswer((_) async => const Right([_bia, _leo, _inativo]));
    when(() => criar(any())).thenAnswer((_) async => Right(_criado));
  });

  BloqueioFormProvider montar({int? somente, int? inicial, DateTime? data}) {
    return BloqueioFormProvider(
      listarColaboradores: listarColaboradores,
      criar: criar,
      somenteColaboradorId: somente,
      colaboradorInicialId: inicial,
      dataInicial: data,
      hoje: _hoje,
    );
  }

  test('o dono escolhe entre a equipe ativa', () async {
    final provider = montar(inicial: 3);

    await provider.carregar();

    expect(provider.colaboradores, [_bia, _leo]);
    expect(provider.colaborador, _leo);
    expect(provider.colaboradorFixo, isFalse);
  });

  test('o parceiro fica fixo na própria agenda', () async {
    final provider = montar(somente: 3, inicial: 2);

    await provider.carregar();

    expect(provider.colaboradores, [_leo]);
    expect(provider.colaborador, _leo);
    expect(provider.colaboradorFixo, isTrue);
  });

  test('aberto de um dia que já passou, começa hoje', () {
    expect(montar(data: DateTime(2026, 11, 1)).dataInicio, _hoje);
  });

  test(
    'salvar manda o período como data de fim e a faixa de horário',
    () async {
      final provider = montar(inicial: 2);
      await provider.carregar();
      provider.selecionarPeriodo(PeriodoDoBloqueio.umaSemana);

      await provider.salvar(motivo: 'Almoço');

      final params =
          verify(() => criar(captureAny())).captured.single
              as NovoBloqueioParams;
      expect(params.colaboradorId, 2);
      expect(params.dataInicio, _hoje);
      expect(params.dataFim, DateTime(2026, 11, 16));
      expect(params.horaInicio, (hora: 12, minuto: 0));
      expect(params.horaFim, (hora: 13, minuto: 0));
      expect(params.motivo, 'Almoço');
      expect(provider.salvo, isTrue);
    },
  );

  test('fixo e dia inteiro vão nulos', () async {
    final provider = montar(inicial: 2);
    await provider.carregar();
    provider
      ..selecionarPeriodo(PeriodoDoBloqueio.fixo)
      ..alterarDiaInteiro(true);

    await provider.salvar();

    final params =
        verify(() => criar(captureAny())).captured.single as NovoBloqueioParams;
    expect(params.dataFim, isNull);
    expect(params.horaInicio, isNull);
    expect(params.horaFim, isNull);
  });

  test('fim antes do início não vai à API', () async {
    final provider = montar(inicial: 2);
    await provider.carregar();
    provider.selecionarHoraFim((hora: 11, minuto: 0));

    await provider.salvar();

    expect(provider.horarioValido, isFalse);
    verifyNever(() => criar(any()));
  });

  test('cliente no período: a mensagem da API vai para a tela', () async {
    when(() => criar(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'Você tem cliente agendado nesse horário.',
          code: 'bloqueio_com_cliente',
        ),
      ),
    );
    final provider = montar(inicial: 2);
    await provider.carregar();

    await provider.salvar();

    expect(provider.errorMessage, 'Você tem cliente agendado nesse horário.');
    expect(provider.salvo, isFalse);
  });

  test('erro de validação vai para o campo', () async {
    when(() => criar(any())).thenAnswer(
      (_) async => const Left(
        ValidationFailure(
          fields: {
            'data_inicio': ['O bloqueio começa hoje ou depois.'],
          },
        ),
      ),
    );
    final provider = montar(inicial: 2);
    await provider.carregar();

    await provider.salvar();

    expect(
      provider.erroDoCampo('data_inicio'),
      'O bloqueio começa hoje ou depois.',
    );
  });

  group('fimDoPeriodo', () {
    final inicio = DateTime(2026, 11, 10);

    test('um dia acaba no próprio dia', () {
      expect(fimDoPeriodo(PeriodoDoBloqueio.umDia, inicio), inicio);
    });

    test('uma semana são sete dias contando o início', () {
      expect(
        fimDoPeriodo(PeriodoDoBloqueio.umaSemana, inicio),
        DateTime(2026, 11, 16),
      );
    });

    test('um mês vai até a véspera do mesmo dia no mês seguinte', () {
      expect(
        fimDoPeriodo(PeriodoDoBloqueio.umMes, inicio),
        DateTime(2026, 12, 9),
      );
    });

    test('fixo não tem fim', () {
      expect(fimDoPeriodo(PeriodoDoBloqueio.fixo, inicio), isNull);
    });
  });
}
