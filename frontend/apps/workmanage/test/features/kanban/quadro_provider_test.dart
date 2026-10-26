import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/agenda/domain/usecases/agenda_use_cases.dart';
import 'package:managers/features/clientes/domain/entities/objeto_cliente.dart';
import 'package:managers/features/kanban/domain/entities/atendimento_kanban.dart';
import 'package:managers/features/kanban/domain/entities/etapa.dart';
import 'package:managers/features/kanban/domain/params/kanban_params.dart';
import 'package:managers/features/kanban/domain/usecases/kanban_use_cases.dart';
import 'package:managers/features/kanban/presentation/providers/quadro_provider.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/listar_colaboradores_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockListarEtapas extends Mock implements ListarEtapasUseCase {}

class _MockListarDoDia extends Mock implements ListarAtendimentosDoDiaUseCase {}

class _MockMover extends Mock implements MoverAtendimentoUseCase {}

class _MockListarPendencias extends Mock implements ListarPendenciasUseCase {}

class _MockListarColaboradores extends Mock
    implements ListarColaboradoresUseCase {}

const _joao = Colaborador(id: 2, nome: 'João');

const _aguardando = Etapa(id: 1, nome: 'Aguardando', ordem: 0);
const _lavando = Etapa(id: 2, nome: 'Lavando', ordem: 1);
const _uno = Veiculo(
  id: 10,
  clienteId: 7,
  placa: 'ABC1D23',
  marca: 'Fiat',
  modelo: 'Uno',
  cor: 'Prata',
);
final _hoje = DateTime(2026, 10, 25);

AtendimentoKanban _card(int id, {int etapaId = 1, Hora? hora}) =>
    AtendimentoKanban(
      id: id,
      etapaId: etapaId,
      etapaNome: 'Aguardando',
      objeto: const ObjetoCliente.veiculo(_uno),
      clienteNome: 'Ana',
      servicoId: 3,
      servicoNome: 'Lavagem',
      servicoPreco: Decimal.fromInt(60),
      data: _hoje,
      horarioEntrada: hora,
    );

void main() {
  late _MockListarEtapas listarEtapas;
  late _MockListarDoDia listarDoDia;
  late _MockMover mover;
  late _MockListarPendencias listarPendencias;
  late _MockListarColaboradores listarColaboradores;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(_hoje);
    registerFallbackValue(ListarDoDiaParams(data: _hoje));
    registerFallbackValue(const MoverAtendimentoParams(id: 0, etapaId: 0));
  });

  QuadroProvider montar() => QuadroProvider(
    listarEtapas: listarEtapas,
    listarDoDia: listarDoDia,
    mover: mover,
    listarPendencias: listarPendencias,
    listarColaboradores: listarColaboradores,
    hoje: _hoje,
  );

  setUp(() {
    listarEtapas = _MockListarEtapas();
    listarDoDia = _MockListarDoDia();
    mover = _MockMover();
    listarPendencias = _MockListarPendencias();
    listarColaboradores = _MockListarColaboradores();
    when(() => listarColaboradores(any()))
        .thenAnswer((_) async => const Right([_joao]));
    when(() => listarEtapas(any()))
        .thenAnswer((_) async => const Right([_aguardando, _lavando]));
    when(() => listarDoDia(any())).thenAnswer(
      (_) async => Right([
        _card(1),
        _card(2, hora: (hora: 10, minuto: 0)),
        _card(3, hora: (hora: 9, minuto: 0)),
        _card(4, etapaId: 2),
      ]),
    );
    when(() => listarPendencias(any()))
        .thenAnswer((_) async => const Right([]));
  });

  test('carregar traz as etapas e os cards de cada coluna, com hora marcada '
      'primeiro', () async {
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isTrue);
    expect(provider.etapas, [_aguardando, _lavando]);
    expect(provider.naEtapa(1).map((a) => a.id), [3, 2, 1]);
    expect(provider.naEtapa(2).map((a) => a.id), [4]);
    expect(provider.pendencias, 0);
    final params =
        verify(() => listarDoDia(captureAny())).captured.single
            as ListarDoDiaParams;
    expect(params.data, _hoje);
    expect(params.colaboradorId, isNull);
  });

  test('selecionarDia recarrega o quadro daquele dia', () async {
    final provider = montar();
    await provider.carregar();

    await provider.selecionarDia(DateTime(2026, 10, 26, 8));

    expect(provider.dia, DateTime(2026, 10, 26));
    expect(provider.ehHoje, isFalse);
    expect(
      (verify(() => listarDoDia(captureAny())).captured.last
              as ListarDoDiaParams)
          .data,
      DateTime(2026, 10, 26),
    );
  });

  test('mover manda o destino e relê o quadro; erro fica na tela', () async {
    when(() => mover(any()))
        .thenAnswer((_) async => Right(_card(1, etapaId: 2)));
    final provider = montar();
    await provider.carregar();

    await provider.mover(1, 2);

    final params =
        verify(() => mover(captureAny())).captured.single
            as MoverAtendimentoParams;
    expect((params.id, params.etapaId), (1, 2));
    verify(() => listarDoDia(any())).called(2);

    when(() => mover(any())).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'Etapa não encontrada.')),
    );
    await provider.mover(1, 9);

    expect(provider.errorMessage, 'Etapa não encontrada.');
    expect(provider.isLoading, isFalse);
  });

  test('erro nas etapas ou no dia vira erroAoCarregar', () async {
    when(() => listarEtapas(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isFalse);
    expect(provider.erroAoCarregar, isA<NetworkFailure>());
  });

  test(
    'filtrar por profissional manda o id e a equipe ativa vem uma vez',
    () async {
      final provider = montar();
      await provider.carregar();
      expect(provider.colaboradores, [_joao]);

      await provider.filtrarColaborador(2);

      final params =
          verify(() => listarDoDia(captureAny())).captured.last
              as ListarDoDiaParams;
      expect(params.colaboradorId, 2);
      expect(provider.colaboradorId, 2);
      verify(() => listarColaboradores(any())).called(1);
    },
  );
}
