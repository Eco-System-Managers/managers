import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/agenda/domain/entities/agendamento.dart';
import 'package:managers/features/agenda/domain/entities/pendencia_cobranca.dart';
import 'package:managers/features/agenda/domain/params/agenda_params.dart';
import 'package:managers/features/agenda/domain/usecases/agenda_use_cases.dart';
import 'package:managers/features/agenda/presentation/providers/agenda_dia_provider.dart';
import 'package:managers/features/empresa/domain/entities/horario_funcionamento.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_horarios_use_case.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';
import 'package:managers/features/servicos/domain/params/listar_servicos_params.dart';
import 'package:managers/features/servicos/domain/usecases/listar_servicos_use_case.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/listar_colaboradores_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockListarDoDia extends Mock implements ListarAgendamentosDoDiaUseCase {}

class _MockListarDias extends Mock implements ListarDiasComRegistroUseCase {}

class _MockListarColaboradores extends Mock
    implements ListarColaboradoresUseCase {}

class _MockListarPendencias extends Mock implements ListarPendenciasUseCase {}

class _MockBuscarHorarios extends Mock implements BuscarHorariosUseCase {}

class _MockListarServicos extends Mock implements ListarServicosUseCase {}

final _hoje = DateTime(2026, 10, 25);

Agendamento _agendamento(int id) => Agendamento(
  id: id,
  clienteId: 7,
  clienteNome: 'Ana',
  dataHora: DateTime(2026, 10, 25, 10, 30),
);

const _bia = Colaborador(id: 2, nome: 'Bia', email: 'bia@demo.com');
const _inativo = Colaborador(
  id: 3,
  nome: 'Caio',
  email: 'caio@demo.com',
  ativo: false,
);

PendenciaCobranca _pendencia(int id) => PendenciaCobranca(
  origemAgenda: true,
  id: id,
  data: DateTime(2026, 10, 20),
  clienteId: 7,
  clienteNome: 'Ana',
  servicoNome: 'Corte',
  valor: Decimal.fromInt(45),
);

void main() {
  late _MockListarDoDia listarDoDia;
  late _MockListarDias listarDias;
  late _MockListarColaboradores listarColaboradores;
  late _MockListarPendencias listarPendencias;
  late _MockBuscarHorarios buscarHorarios;
  late _MockListarServicos listarServicos;

  setUpAll(() {
    registerFallbackValue(ListarAgendamentosDoDiaParams(data: _hoje));
    registerFallbackValue(const MesParams(ano: 2026, mes: 10));
    registerFallbackValue(NoParams());
    registerFallbackValue(const ListarServicosParams());
  });

  AgendaDiaProvider montar() {
    return AgendaDiaProvider(
      listarDoDia: listarDoDia,
      listarDiasComRegistro: listarDias,
      listarColaboradores: listarColaboradores,
      listarPendencias: listarPendencias,
      buscarHorarios: buscarHorarios,
      listarServicos: listarServicos,
      hoje: _hoje,
    );
  }

  setUp(() {
    listarDoDia = _MockListarDoDia();
    listarDias = _MockListarDias();
    listarColaboradores = _MockListarColaboradores();
    listarPendencias = _MockListarPendencias();
    buscarHorarios = _MockBuscarHorarios();
    listarServicos = _MockListarServicos();
    // 25/10/2026 é domingo: aberto das 9 às 13; segunda fechada
    when(() => buscarHorarios(any())).thenAnswer(
      (_) async => const Right([
        HorarioFuncionamento(
          dia: DiaSemana.domingo,
          abertura: HoraDoDia(9, 0),
          fechamento: HoraDoDia(13, 0),
        ),
        HorarioFuncionamento(dia: DiaSemana.segunda, ativo: false),
      ]),
    );
    when(() => listarServicos(any())).thenAnswer(
      (_) async => Right([
        Servico(id: 1, nome: 'Corte', duracao: 40, preco: Decimal.fromInt(40)),
        Servico(id: 2, nome: 'Barba', duracao: 20, preco: Decimal.fromInt(20)),
      ]),
    );
    when(() => listarDoDia(any()))
        .thenAnswer((_) async => Right([_agendamento(1)]));
    when(() => listarDias(any())).thenAnswer(
      (_) async => Right([DateTime(2026, 10, 25), DateTime(2026, 10, 3)]),
    );
    when(() => listarColaboradores(any()))
        .thenAnswer((_) async => const Right([_bia, _inativo]));
    when(() => listarPendencias(any()))
        .thenAnswer((_) async => Right([_pendencia(4)]));
  });

  test(
    'carregar traz o dia, as bolinhas do mês, a equipe ativa e as pendências',
    () async {
      final provider = montar();
      expect(provider.ehHoje, isTrue);

      await provider.carregar();

      expect(provider.carregado, isTrue);
      expect(provider.agendamentos.map((a) => a.id), [1]);
      expect(provider.temRegistro(DateTime(2026, 10, 3)), isTrue);
      expect(provider.temRegistro(DateTime(2026, 10, 4)), isFalse);
      expect(provider.colaboradores, [_bia]);
      expect(provider.pendencias, 1);
      final params =
          verify(() => listarDoDia(captureAny())).captured.single
              as ListarAgendamentosDoDiaParams;
      expect(params.data, _hoje);
      expect(params.colaboradorId, isNull);
    },
  );

  test(
    'selecionarDia troca o dia e recarrega; o mesmo dia não vai à API',
    () async {
      final provider = montar();
      await provider.carregar();

      await provider.selecionarDia(DateTime(2026, 10, 26, 15));

      expect(provider.dia, DateTime(2026, 10, 26));
      expect(provider.ehHoje, isFalse);
      final params =
          verify(() => listarDoDia(captureAny())).captured.last
              as ListarAgendamentosDoDiaParams;
      expect(params.data, DateTime(2026, 10, 26));
      // o mês já estava em cache: as bolinhas não são buscadas de novo
      verify(() => listarDias(any())).called(1);

      await provider.selecionarDia(DateTime(2026, 10, 26));
      verifyNever(() => listarDoDia(any()));
    },
  );

  test('filtrarColaborador recarrega com o id; irParaHoje volta', () async {
    final provider = montar();
    await provider.carregar();

    await provider.filtrarColaborador(2);

    expect(provider.colaboradorId, 2);
    final params =
        verify(() => listarDoDia(captureAny())).captured.last
            as ListarAgendamentosDoDiaParams;
    expect(params.colaboradorId, 2);

    await provider.selecionarDia(DateTime(2026, 10, 1));
    await provider.irParaHoje();
    expect(provider.ehHoje, isTrue);
  });

  test(
    'erro ao listar o dia vira erroAoCarregar; bolinhas falhando não',
    () async {
      when(() => listarDoDia(any()))
          .thenAnswer((_) async => const Left(NetworkFailure()));
      when(() => listarDias(any()))
          .thenAnswer((_) async => const Left(ServerFailure()));
      final provider = montar();

      await provider.carregar();

      expect(provider.carregado, isFalse);
      expect(provider.erroAoCarregar, isA<NetworkFailure>());
      expect(provider.temRegistro(_hoje), isFalse);
    },
  );

  test('garantirMesesVisiveis busca só os meses que faltam', () async {
    final provider = montar();
    await provider.carregar();

    await provider.garantirMesesVisiveis([
      DateTime(2026, 10, 28),
      DateTime(2026, 11, 1),
      DateTime(2026, 11, 2),
    ]);

    final meses = verify(() => listarDias(captureAny())).captured
        .cast<MesParams>();
    expect(meses.map((m) => (m.ano, m.mes)), [(2026, 10), (2026, 11)]);
  });

  test('recarregar esquece as bolinhas e busca tudo de novo', () async {
    final provider = montar();
    await provider.carregar();

    await provider.recarregar();

    verify(() => listarDias(any())).called(2);
    verify(() => listarDoDia(any())).called(2);
  });

  test(
    'expediente do dia vem dos horários e o passo do menor serviço',
    () async {
      final provider = montar();

      await provider.carregar();

      expect(provider.expedienteDoDia?.abertura.emMinutos, 9 * 60);
      expect(provider.expedienteDoDia?.fechamento.emMinutos, 13 * 60);
      expect(provider.passoMinutos, 20);
      // os horários e os serviços vão à API uma vez só
      await provider.selecionarDia(DateTime(2026, 10, 26));
      verify(() => buscarHorarios(any())).called(1);
      verify(() => listarServicos(any())).called(1);
      // segunda fechada: sem expediente
      expect(provider.expedienteDoDia, isNull);
    },
  );

  test(
    'sem serviço ativo o passo é o padrão; com serviço de 5 min, o mínimo',
    () async {
      when(() => listarServicos(any()))
          .thenAnswer((_) async => const Right([]));
      final provider = montar();
      await provider.carregar();
      expect(provider.passoMinutos, passoPadrao);

      when(() => listarServicos(any())).thenAnswer(
        (_) async => Right([
          Servico(id: 3, nome: 'Rápido', duracao: 5, preco: Decimal.fromInt(5)),
        ]),
      );
      final outro = montar();
      await outro.carregar();
      expect(outro.passoMinutos, passoMinimo);
    },
  );
}
