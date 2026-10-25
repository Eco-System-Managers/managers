import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/lista_paginada.dart';
import 'package:managers/features/agenda/domain/entities/agendamento.dart';
import 'package:managers/features/agenda/domain/entities/slot.dart';
import 'package:managers/features/agenda/domain/params/agenda_params.dart';
import 'package:managers/features/agenda/domain/usecases/agenda_use_cases.dart';
import 'package:managers/features/agenda/presentation/providers/agendamento_form_provider.dart';
import 'package:managers/features/clientes/domain/entities/cliente.dart';
import 'package:managers/features/clientes/domain/params/listar_clientes_params.dart';
import 'package:managers/features/clientes/domain/usecases/listar_clientes_use_case.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';
import 'package:managers/features/servicos/domain/params/listar_servicos_params.dart';
import 'package:managers/features/servicos/domain/usecases/listar_servicos_use_case.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/listar_colaboradores_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockListarServicos extends Mock implements ListarServicosUseCase {}

class _MockListarColaboradores extends Mock
    implements ListarColaboradoresUseCase {}

class _MockListarClientes extends Mock implements ListarClientesUseCase {}

class _MockListarSlots extends Mock implements ListarSlotsUseCase {}

class _MockCriar extends Mock implements CriarAgendamentoUseCase {}

final _corte = Servico(
  id: 3,
  nome: 'Corte',
  duracao: 30,
  preco: Decimal.parse('45.50'),
);

// só a Dani faz barba
final _barba = Servico(
  id: 4,
  nome: 'Barba',
  duracao: 20,
  preco: Decimal.fromInt(30),
  colaboradores: const [5],
);

const _bia = Colaborador(id: 2, nome: 'Bia', email: 'bia@demo.com');
const _dani = Colaborador(id: 5, nome: 'Dani', email: 'dani@demo.com');
const _inativo = Colaborador(
  id: 3,
  nome: 'Caio',
  email: 'caio@demo.com',
  ativo: false,
);
const _ana = Cliente(id: 7, nome: 'Ana', telefone: '19999990000');
final _dia = DateTime(2026, 10, 25);
const _nove = (hora: 9, minuto: 0);
const _slots = [
  Slot(hora: _nove, disponivel: true),
  Slot(hora: (hora: 9, minuto: 30), disponivel: false),
];

final _criado = Agendamento(
  id: 9,
  clienteId: 7,
  clienteNome: 'Ana',
  dataHora: DateTime(2026, 10, 25, 9),
);

void main() {
  late _MockListarServicos listarServicos;
  late _MockListarColaboradores listarColaboradores;
  late _MockListarClientes listarClientes;
  late _MockListarSlots listarSlots;
  late _MockCriar criar;

  setUpAll(() {
    registerFallbackValue(const ListarServicosParams());
    registerFallbackValue(NoParams());
    registerFallbackValue(const ListarClientesParams());
    registerFallbackValue(
      SlotsParams(data: _dia, servicoId: 0, colaboradorId: 0),
    );
    registerFallbackValue(
      NovoAgendamentoParams(
        clienteId: 0,
        servicoId: 0,
        colaboradorId: null,
        dataHora: _dia,
      ),
    );
  });

  AgendamentoFormProvider montar({int? colaboradorInicialId = 2}) {
    return AgendamentoFormProvider(
      listarServicos: listarServicos,
      listarColaboradores: listarColaboradores,
      listarClientes: listarClientes,
      listarSlots: listarSlots,
      criar: criar,
      colaboradorInicialId: colaboradorInicialId,
      dataInicial: _dia,
    );
  }

  // o caminho feliz até a hora escolhida
  Future<AgendamentoFormProvider> pronto() async {
    final provider = montar();
    await provider.carregar();
    provider.selecionarCliente(_ana);
    provider.selecionarServico(_corte);
    await pumpEventQueue();
    provider.selecionarHora(_nove);
    return provider;
  }

  setUp(() {
    listarServicos = _MockListarServicos();
    listarColaboradores = _MockListarColaboradores();
    listarClientes = _MockListarClientes();
    listarSlots = _MockListarSlots();
    criar = _MockCriar();
    when(() => listarServicos(any()))
        .thenAnswer((_) async => Right([_corte, _barba]));
    when(() => listarColaboradores(any()))
        .thenAnswer((_) async => const Right([_bia, _dani, _inativo]));
    when(() => listarSlots(any())).thenAnswer((_) async => const Right(_slots));
    when(() => listarClientes(any())).thenAnswer(
      (_) async =>
          const Right(ListaPaginada(itens: [_ana], total: 1, temMais: false)),
    );
    when(() => criar(any())).thenAnswer((_) async => Right(_criado));
  });

  test('carregar traz serviços ativos e equipe ativa, com quem entrou já '
      'escolhido', () async {
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isTrue);
    final params =
        verify(() => listarServicos(captureAny())).captured.single
            as ListarServicosParams;
    expect(params.ativo, isTrue);
    expect(provider.servicos, [_corte, _barba]);
    expect(provider.colaboradores, [_bia, _dani]);
    expect(provider.colaborador, _bia);
    expect(provider.data, _dia);
    expect(provider.prontoParaGrade, isFalse);
    verifyNever(() => listarSlots(any()));
  });

  test('com serviço e profissional a grade é buscada; trocar o serviço limpa '
      'a hora e quem não o executa', () async {
    final provider = montar();
    await provider.carregar();

    provider.selecionarServico(_corte);
    await pumpEventQueue();

    expect(provider.prontoParaGrade, isTrue);
    expect(provider.slots, _slots);
    final params =
        verify(() => listarSlots(captureAny())).captured.single as SlotsParams;
    expect((params.data, params.servicoId, params.colaboradorId), (_dia, 3, 2));

    provider.selecionarHora(_nove);
    expect(provider.hora, _nove);

    provider.selecionarServico(_barba);
    await pumpEventQueue();

    // a Bia não faz barba: sai da escolha e da lista, e a grade some
    expect(provider.colaborador, isNull);
    expect(provider.hora, isNull);
    expect(provider.colaboradores, [_dani]);
    expect(provider.prontoParaGrade, isFalse);
    verifyNever(() => listarSlots(any()));

    provider.selecionarColaborador(_dani);
    await pumpEventQueue();

    final deNovo =
        verify(() => listarSlots(captureAny())).captured.single as SlotsParams;
    expect((deNovo.servicoId, deNovo.colaboradorId), (4, 5));
  });

  test('selecionarData recarrega a grade para o novo dia', () async {
    final provider = montar();
    await provider.carregar();
    provider.selecionarServico(_corte);
    await pumpEventQueue();
    provider.selecionarHora(_nove);

    provider.selecionarData(DateTime(2026, 10, 26, 8));
    await pumpEventQueue();

    expect(provider.data, DateTime(2026, 10, 26));
    expect(provider.hora, isNull);
    final params =
        verify(() => listarSlots(captureAny())).captured.last as SlotsParams;
    expect(params.data, DateTime(2026, 10, 26));
  });

  test('salvar monta o agendamento com dia e hora e fecha', () async {
    final provider = await pronto();

    await provider.salvar(observacoes: 'Sem máquina');

    final enviado =
        verify(() => criar(captureAny())).captured.single
            as NovoAgendamentoParams;
    expect(enviado.clienteId, 7);
    expect(enviado.servicoId, 3);
    expect(enviado.colaboradorId, 2);
    expect(enviado.dataHora, DateTime(2026, 10, 25, 9));
    expect(enviado.observacoes, 'Sem máquina');
    expect(provider.salvo, isTrue);
    expect(provider.criado, _criado);
  });

  test('sem cliente, serviço ou hora, salvar não vai à API', () async {
    final provider = montar();
    await provider.carregar();

    await provider.salvar();

    verifyNever(() => criar(any()));
    expect(provider.salvo, isFalse);
  });

  test(
    'conflito de horário: mensagem, hora limpa e grade recarregada',
    () async {
      when(() => criar(any())).thenAnswer(
        (_) async => const Left(
          ServerFailure(
            message: 'Esse colaborador já tem um agendamento nesse horário.',
            code: 'horario_conflito',
          ),
        ),
      );
      final provider = await pronto();

      await provider.salvar();
      await pumpEventQueue();

      expect(provider.salvo, isFalse);
      expect(provider.errorMessage, contains('já tem um agendamento'));
      expect(provider.hora, isNull);
      verify(() => listarSlots(any())).called(2);
    },
  );

  test('erro de validação vai para o campo e some ao mexer nele', () async {
    when(() => criar(any())).thenAnswer(
      (_) async => const Left(
        ValidationFailure(
          fields: {
            'cliente': ['Cliente inválido.'],
          },
        ),
      ),
    );
    final provider = await pronto();

    await provider.salvar();

    expect(provider.salvo, isFalse);
    expect(provider.erroDoCampo('cliente'), 'Cliente inválido.');
    expect(provider.errorMessage, isNull);

    provider.selecionarCliente(_ana);
    expect(provider.erroDoCampo('cliente'), isNull);
  });

  test(
    'buscarClientes devolve a primeira página; erro vira lista vazia',
    () async {
      final provider = montar();

      expect(await provider.buscarClientes('ana'), [_ana]);
      final params =
          verify(() => listarClientes(captureAny())).captured.single
              as ListarClientesParams;
      expect(params.busca, 'ana');

      when(() => listarClientes(any()))
          .thenAnswer((_) async => const Left(NetworkFailure()));
      expect(await provider.buscarClientes('x'), isEmpty);
    },
  );

  test('a hora tocada na grade entra escolhida quando a grade de slots chega '
      'livre; ocupada, não', () async {
    AgendamentoFormProvider comHora(Hora hora) => AgendamentoFormProvider(
      listarServicos: listarServicos,
      listarColaboradores: listarColaboradores,
      listarClientes: listarClientes,
      listarSlots: listarSlots,
      criar: criar,
      colaboradorInicialId: 2,
      dataInicial: _dia,
      horaInicial: hora,
    );

    final livre = comHora(_nove);
    await livre.carregar();
    livre.selecionarServico(_corte);
    await pumpEventQueue();
    expect(livre.hora, _nove);

    final ocupada = comHora((hora: 9, minuto: 30));
    await ocupada.carregar();
    ocupada.selecionarServico(_corte);
    await pumpEventQueue();
    expect(ocupada.hora, isNull);
  });
}
