import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/agenda/domain/entities/bloqueio.dart';
import 'package:managers/features/agenda/domain/usecases/agenda_use_cases.dart';
import 'package:managers/features/clientes/domain/entities/objeto_cliente.dart';
import 'package:managers/features/kanban/domain/entities/atendimento_kanban.dart';
import 'package:managers/features/kanban/domain/entities/capacidade_do_dia.dart';
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

class _MockObterCapacidade extends Mock
    implements ObterCapacidadeDoDiaUseCase {}

class _MockAjustarCapacidade extends Mock
    implements AjustarCapacidadeDoDiaUseCase {}

class _MockDesfazerAjuste extends Mock implements DesfazerAjusteDoDiaUseCase {}

class _MockListarBloqueios extends Mock implements ListarBloqueiosDoDiaUseCase {}

class _MockExcluirBloqueio extends Mock implements ExcluirBloqueioUseCase {}

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
final _capacidade = CapacidadeDoDia(
  data: _hoje,
  capacidade: 8,
  vagas: 1,
  ocupados: 3,
);

// os bloqueios que a API lista no dia: dois do negócio e um só do João
final _almoco = Bloqueio(
  id: 5,
  dataInicio: _hoje,
  horaInicio: (hora: 12, minuto: 0),
  horaFim: (hora: 13, minuto: 0),
  motivo: 'Almoço',
);
final _diaTodo = Bloqueio(id: 6, dataInicio: _hoje, motivo: 'Feriado');
final _doJoao = Bloqueio(
  id: 7,
  colaboradorId: 2,
  colaboradorNome: 'João',
  dataInicio: _hoje,
);

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
  late _MockObterCapacidade obterCapacidade;
  late _MockAjustarCapacidade ajustarCapacidade;
  late _MockDesfazerAjuste desfazerAjuste;
  late _MockListarBloqueios listarBloqueios;
  late _MockExcluirBloqueio excluirBloqueio;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(_hoje);
    registerFallbackValue(ListarDoDiaParams(data: _hoje));
    registerFallbackValue(ListarAgendamentosDoDiaParams(data: _hoje));
    registerFallbackValue(const MoverAtendimentoParams(id: 0, etapaId: 0));
    registerFallbackValue(AjustarCapacidadeParams(data: _hoje, vagas: 1));
  });

  QuadroProvider montar() => QuadroProvider(
    listarEtapas: listarEtapas,
    listarDoDia: listarDoDia,
    mover: mover,
    listarPendencias: listarPendencias,
    listarColaboradores: listarColaboradores,
    obterCapacidade: obterCapacidade,
    ajustarCapacidade: ajustarCapacidade,
    desfazerAjuste: desfazerAjuste,
    listarBloqueios: listarBloqueios,
    excluirBloqueio: excluirBloqueio,
    hoje: _hoje,
  );

  setUp(() {
    listarEtapas = _MockListarEtapas();
    listarDoDia = _MockListarDoDia();
    mover = _MockMover();
    listarPendencias = _MockListarPendencias();
    listarColaboradores = _MockListarColaboradores();
    obterCapacidade = _MockObterCapacidade();
    ajustarCapacidade = _MockAjustarCapacidade();
    desfazerAjuste = _MockDesfazerAjuste();
    listarBloqueios = _MockListarBloqueios();
    excluirBloqueio = _MockExcluirBloqueio();
    when(() => obterCapacidade(any()))
        .thenAnswer((_) async => Right(_capacidade));
    when(() => listarBloqueios(any()))
        .thenAnswer((_) async => Right([_almoco, _doJoao, _diaTodo]));
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

  test('carregar traz as etapas, os cards de cada coluna (com hora marcada '
      'primeiro) e a capacidade do dia', () async {
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isTrue);
    expect(provider.etapas, [_aguardando, _lavando]);
    expect(provider.naEtapa(1).map((a) => a.id), [3, 2, 1]);
    expect(provider.naEtapa(2).map((a) => a.id), [4]);
    expect(provider.pendencias, 0);
    expect(provider.capacidade, _capacidade);
    final params =
        verify(() => listarDoDia(captureAny())).captured.single
            as ListarDoDiaParams;
    expect(params.data, _hoje);
    expect(params.colaboradorId, isNull);
    expect(verify(() => obterCapacidade(captureAny())).captured.single, _hoje);
  });

  test('carregar traz só os horários fechados do negócio, o dia todo '
      'primeiro, lidos sem filtro de profissional', () async {
    final provider = montar();

    await provider.carregar();

    expect(provider.bloqueios, [_diaTodo, _almoco]);
    final params =
        verify(() => listarBloqueios(captureAny())).captured.single
            as ListarAgendamentosDoDiaParams;
    expect(params.data, _hoje);
    expect(params.colaboradorId, isNull);
  });

  test('sem os bloqueios o quadro continua, só sem as faixas', () async {
    when(() => listarBloqueios(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isTrue);
    expect(provider.bloqueios, isEmpty);
  });

  test('excluirBloqueio relê o dia; erro vira a mensagem devolvida', () async {
    when(() => excluirBloqueio(5)).thenAnswer((_) async => const Right(null));
    when(() => excluirBloqueio(6)).thenAnswer(
      (_) async => const Left(PermissionFailure(message: 'Sem permissão')),
    );
    final provider = montar();
    await provider.carregar();

    expect(await provider.excluirBloqueio(5), isNull);
    verify(() => listarDoDia(any())).called(2);

    clearInteractions(listarDoDia);
    expect(await provider.excluirBloqueio(6), 'Sem permissão');
    verifyNever(() => listarDoDia(any()));
  });

  test('sem a capacidade o quadro continua, só sem o resumo', () async {
    when(() => obterCapacidade(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isTrue);
    expect(provider.capacidade, isNull);
  });

  test('ajustarCapacidade manda o dia aberto e guarda a resposta; erro vira '
      'a mensagem devolvida', () async {
    final ajustada = CapacidadeDoDia(
      data: _hoje,
      capacidade: 14,
      vagas: 2,
      ajustado: true,
      ocupados: 3,
    );
    when(() => ajustarCapacidade(any()))
        .thenAnswer((_) async => Right(ajustada));
    final provider = montar();
    await provider.carregar();

    final erro = await provider.ajustarCapacidade(capacidade: 14, vagas: 2);

    expect(erro, isNull);
    expect(provider.capacidade, ajustada);
    final params =
        verify(() => ajustarCapacidade(captureAny())).captured.single
            as AjustarCapacidadeParams;
    expect(params.data, _hoje);
    expect(params.capacidade, 14);
    expect(params.vagas, 2);

    when(() => ajustarCapacidade(any())).thenAnswer(
      (_) async => const Left(
        ValidationFailure(
          fields: {
            'vagas': ['Informe pelo menos 1.'],
          },
        ),
      ),
    );
    final mensagem = await provider.ajustarCapacidade(vagas: 0);

    expect(mensagem, 'Informe pelo menos 1.');
    // a capacidade que valia continua
    expect(provider.capacidade, ajustada);
  });

  test('voltarAoPadrao apaga o ajuste do dia aberto', () async {
    when(() => desfazerAjuste(any()))
        .thenAnswer((_) async => Right(_capacidade));
    final provider = montar();
    await provider.carregar();
    await provider.selecionarDia(DateTime(2026, 10, 26));

    final erro = await provider.voltarAoPadrao();

    expect(erro, isNull);
    expect(
      verify(() => desfazerAjuste(captureAny())).captured.single,
      DateTime(2026, 10, 26),
    );
    expect(provider.capacidade, _capacidade);
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
    'filtrar por profissional manda o id e a equipe recarrega junto',
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
      // a equipe vem de novo a cada carga: quem entrou depois aparece no filtro
      verify(() => listarColaboradores(any())).called(2);
    },
  );
}
