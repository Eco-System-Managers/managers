import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/lista_paginada.dart';
import 'package:managers/features/clientes/domain/entities/cliente.dart';
import 'package:managers/features/clientes/domain/entities/objeto_cliente.dart';
import 'package:managers/features/clientes/domain/params/listar_clientes_params.dart';
import 'package:managers/features/clientes/domain/usecases/listar_clientes_use_case.dart';
import 'package:managers/features/clientes/domain/usecases/obter_cliente_use_case.dart';
import 'package:managers/features/kanban/domain/entities/atendimento_kanban.dart';
import 'package:managers/features/kanban/domain/entities/etapa.dart';
import 'package:managers/features/kanban/domain/params/kanban_params.dart';
import 'package:managers/features/kanban/domain/usecases/kanban_use_cases.dart';
import 'package:managers/features/kanban/presentation/providers/atendimento_kanban_form_provider.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';
import 'package:managers/features/servicos/domain/params/listar_servicos_params.dart';
import 'package:managers/features/servicos/domain/usecases/listar_servicos_use_case.dart';
import 'package:managers/features/usuarios/domain/usecases/listar_colaboradores_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockListarEtapas extends Mock implements ListarEtapasUseCase {}

class _MockListarServicos extends Mock implements ListarServicosUseCase {}

class _MockListarClientes extends Mock implements ListarClientesUseCase {}

class _MockObterCliente extends Mock implements ObterClienteUseCase {}

class _MockListarSlots extends Mock implements ListarSlotsKanbanUseCase {}

class _MockCriar extends Mock implements CriarAtendimentoKanbanUseCase {}

class _MockListarColaboradores extends Mock
    implements ListarColaboradoresUseCase {}

const _aguardando = Etapa(id: 1, nome: 'Aguardando', ordem: 0);
const _lavando = Etapa(id: 2, nome: 'Lavando', ordem: 1);
final _lavagem = Servico(
  id: 3,
  nome: 'Lavagem',
  duracao: 40,
  preco: Decimal.fromInt(60),
);
const _uno = Veiculo(
  id: 10,
  clienteId: 7,
  placa: 'ABC1D23',
  marca: 'Fiat',
  modelo: 'Uno',
  cor: 'Prata',
);
const _gol = Veiculo(
  id: 11,
  clienteId: 7,
  placa: 'XYZ9A88',
  marca: 'VW',
  modelo: 'Gol',
  cor: 'Preto',
);
const _ana = Cliente(
  id: 7,
  nome: 'Ana',
  telefone: '19999990000',
  veiculos: [_uno],
);
final _dia = DateTime(2026, 10, 25);
const _nove = (hora: 9, minuto: 0);
const _dez = (hora: 10, minuto: 0);

final _criado = AtendimentoKanban(
  id: 9,
  etapaId: 1,
  etapaNome: 'Aguardando',
  objeto: const ObjetoCliente.veiculo(_uno),
  clienteNome: 'Ana',
  servicoId: 3,
  servicoNome: 'Lavagem',
  servicoPreco: Decimal.fromInt(60),
);

void main() {
  late _MockListarEtapas listarEtapas;
  late _MockListarServicos listarServicos;
  late _MockListarClientes listarClientes;
  late _MockObterCliente obterCliente;
  late _MockListarSlots listarSlots;
  late _MockCriar criar;
  late _MockListarColaboradores listarColaboradores;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(const ListarServicosParams());
    registerFallbackValue(const ListarClientesParams());
    registerFallbackValue(SlotsKanbanParams(data: _dia));
    registerFallbackValue(
      NovoAtendimentoParams(etapaId: 0, objetoId: 0, servicoId: 0, data: _dia),
    );
  });

  AtendimentoKanbanFormProvider montar() => AtendimentoKanbanFormProvider(
    listarEtapas: listarEtapas,
    listarServicos: listarServicos,
    listarClientes: listarClientes,
    obterCliente: obterCliente,
    listarSlots: listarSlots,
    listarColaboradores: listarColaboradores,
    criar: criar,
    tipoObjeto: TipoObjeto.veiculo,
    dataInicial: _dia,
  );

  setUp(() {
    listarEtapas = _MockListarEtapas();
    listarServicos = _MockListarServicos();
    listarClientes = _MockListarClientes();
    obterCliente = _MockObterCliente();
    listarSlots = _MockListarSlots();
    criar = _MockCriar();
    listarColaboradores = _MockListarColaboradores();
    when(() => listarColaboradores(any()))
        .thenAnswer((_) async => const Right([]));
    when(() => listarEtapas(any()))
        .thenAnswer((_) async => const Right([_aguardando, _lavando]));
    when(() => listarServicos(any()))
        .thenAnswer((_) async => Right([_lavagem]));
    when(() => listarSlots(any()))
        .thenAnswer((_) async => const Right([_nove, _dez]));
    when(() => listarClientes(any())).thenAnswer(
      (_) async =>
          const Right(ListaPaginada(itens: [_ana], total: 1, temMais: false)),
    );
    when(() => criar(any())).thenAnswer((_) async => Right(_criado));
  });

  test(
    'carregar traz etapas, serviços ativos e as horas livres do dia',
    () async {
      final provider = montar();

      await provider.carregar();

      expect(provider.carregado, isTrue);
      expect(provider.etapaDeEntrada, _aguardando);
      expect(provider.servicos, [_lavagem]);
      expect(provider.slots, [_nove, _dez]);
      final params =
          verify(() => listarServicos(captureAny())).captured.single
              as ListarServicosParams;
      expect(params.ativo, isTrue);
    },
  );

  test('cliente com um só veículo já entra escolhido; o novo cadastrado vira '
      'o escolhido', () async {
    when(() => obterCliente(7)).thenAnswer(
      (_) async => const Right(
        Cliente(
          id: 7,
          nome: 'Ana',
          telefone: '19999990000',
          veiculos: [_uno, _gol],
        ),
      ),
    );
    final provider = montar();
    await provider.carregar();

    provider.selecionarCliente(_ana);
    expect(provider.objeto, const ObjetoCliente.veiculo(_uno));

    await provider.recarregarCliente();
    expect(provider.objetos, hasLength(2));
    // o escolhido continua: ele ainda existe
    expect(provider.objeto, const ObjetoCliente.veiculo(_uno));

    provider.selecionarObjeto(null);
    await provider.recarregarCliente();
    // sem escolha, o mais novo
    expect(provider.objeto, const ObjetoCliente.veiculo(_gol));
  });

  group('porte', () {
    final lavagemMoto = Servico(
      id: 4,
      nome: 'Lavagem moto',
      porte: Porte.moto,
      duracao: 20,
      preco: Decimal.fromInt(25),
    );
    final lavagemCarro = Servico(
      id: 5,
      nome: 'Lavagem carro',
      porte: Porte.carro,
      duracao: 40,
      preco: Decimal.fromInt(40),
    );
    const unoCarro = Veiculo(
      id: 10,
      clienteId: 7,
      placa: 'ABC1D23',
      marca: 'Fiat',
      modelo: 'Uno',
      cor: 'Prata',
      porte: Porte.carro,
    );
    const cg = Veiculo(
      id: 12,
      clienteId: 7,
      placa: 'MOT0A12',
      marca: 'Honda',
      modelo: 'CG',
      cor: 'Vermelha',
      porte: Porte.moto,
    );

    Future<AtendimentoKanbanFormProvider> carregado(
      List<Servico> servicos,
    ) async {
      when(() => listarServicos(any()))
          .thenAnswer((_) async => Right(servicos));
      final provider = montar();
      await provider.carregar();
      return provider;
    }

    test('os serviços seguem o porte do veículo escolhido', () async {
      final provider = await carregado([_lavagem, lavagemMoto, lavagemCarro]);
      // sem veículo, todos
      expect(provider.servicos, [_lavagem, lavagemMoto, lavagemCarro]);

      provider.selecionarCliente(
        const Cliente(
          id: 7,
          nome: 'Ana',
          telefone: '19999990000',
          veiculos: [unoCarro],
        ),
      );

      // os do porte e os que valem para qualquer um
      expect(provider.servicos, [_lavagem, lavagemCarro]);
    });

    test('veículo sem porte vê todos os serviços', () async {
      final provider = await carregado([_lavagem, lavagemMoto, lavagemCarro]);

      provider.selecionarCliente(_ana);

      expect(provider.objeto!.porte, isNull);
      expect(provider.servicos, hasLength(3));
    });

    test('trocar para um veículo de outro porte solta o serviço que não '
        'serve', () async {
      final provider = await carregado([_lavagem, lavagemMoto, lavagemCarro]);
      provider.selecionarCliente(
        const Cliente(
          id: 7,
          nome: 'Ana',
          telefone: '19999990000',
          veiculos: [unoCarro, cg],
        ),
      );
      provider.selecionarObjeto(const ObjetoCliente.veiculo(unoCarro));
      provider.selecionarServico(_lavagem);

      // o sem porte serve para os dois
      provider.selecionarObjeto(const ObjetoCliente.veiculo(cg));
      expect(provider.servico, _lavagem);

      provider.selecionarServico(lavagemMoto);
      provider.selecionarObjeto(const ObjetoCliente.veiculo(unoCarro));
      expect(provider.servico, isNull);
    });

    test('avisa quando nenhum serviço serve para o porte', () async {
      final provider = await carregado([lavagemMoto]);

      provider.selecionarCliente(
        const Cliente(
          id: 7,
          nome: 'Ana',
          telefone: '19999990000',
          veiculos: [unoCarro],
        ),
      );

      expect(provider.servicos, isEmpty);
      expect(provider.nenhumServicoParaOPorte, isTrue);
    });

    test('informar o porte na folha: o mesmo veículo continua escolhido, '
        'agora com o porte', () async {
      // o Gol é mais novo, mas quem estava escolhido era o Uno
      when(() => obterCliente(7)).thenAnswer(
        (_) async => const Right(
          Cliente(
            id: 7,
            nome: 'Ana',
            telefone: '19999990000',
            veiculos: [unoCarro, _gol],
          ),
        ),
      );
      final provider = await carregado([_lavagem, lavagemMoto, lavagemCarro]);
      provider.selecionarCliente(_ana);

      await provider.recarregarCliente();

      expect(provider.objeto, const ObjetoCliente.veiculo(unoCarro));
      expect(provider.servicos, [_lavagem, lavagemCarro]);
    });
  });

  test('selecionarData limpa a hora e recarrega a grade', () async {
    final provider = montar();
    await provider.carregar();
    provider.selecionarHora(_nove);

    provider.selecionarData(DateTime(2026, 10, 26));
    await pumpEventQueue();

    expect(provider.hora, isNull);
    final params =
        verify(() => listarSlots(captureAny())).captured.last
            as SlotsKanbanParams;
    expect(params.data, DateTime(2026, 10, 26));
  });

  test('a grade segue o serviço: trocar recarrega com o servicoId e a hora '
      'que saiu da grade é limpa', () async {
    final provider = montar();
    await provider.carregar();
    // sem serviço, a grade vem sem ele
    final semServico =
        verify(() => listarSlots(captureAny())).captured.single
            as SlotsKanbanParams;
    expect(semServico.servicoId, isNull);
    provider.selecionarHora(_nove);

    when(() => listarSlots(any())).thenAnswer((_) async => const Right([_dez]));
    provider.selecionarServico(_lavagem);
    await pumpEventQueue();

    final params =
        verify(() => listarSlots(captureAny())).captured.single
            as SlotsKanbanParams;
    expect(params.servicoId, 3);
    expect(params.data, _dia);
    expect(provider.slots, [_dez]);
    // 09:00 não está mais na grade: a hora sai
    expect(provider.hora, isNull);

    // o mesmo serviço de novo não busca
    provider.selecionarServico(_lavagem);
    await pumpEventQueue();
    verifyNever(() => listarSlots(any()));
  });

  test('salvar monta o atendimento na primeira etapa e fecha', () async {
    final provider = montar();
    await provider.carregar();
    provider.selecionarCliente(_ana);
    provider.selecionarServico(_lavagem);
    provider.selecionarHora(_dez);

    await provider.salvar(observacao: 'Chaves no painel');

    final enviado =
        verify(() => criar(captureAny())).captured.single
            as NovoAtendimentoParams;
    expect(enviado.etapaId, 1);
    expect(enviado.objetoId, 10);
    expect(enviado.servicoId, 3);
    expect(enviado.data, _dia);
    expect(enviado.horarioEntrada, _dez);
    expect(enviado.observacao, 'Chaves no painel');
    expect(provider.salvo, isTrue);
  });

  test('sem objeto ou serviço, salvar não vai à API', () async {
    final provider = montar();
    await provider.carregar();

    await provider.salvar();

    verifyNever(() => criar(any()));
  });

  test('hora sem vaga vira pergunta; desistir limpa a hora e recarrega a '
      'grade', () async {
    when(() => criar(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'Esse horário já foi reservado. Escolha outro.',
          code: 'horario_ocupado',
        ),
      ),
    );
    final provider = montar();
    await provider.carregar();
    provider.selecionarCliente(_ana);
    provider.selecionarServico(_lavagem);
    await pumpEventQueue();
    provider.selecionarHora(_dez);

    await provider.salvar();

    expect(provider.salvo, isFalse);
    expect(provider.limiteEstourado, contains('já foi reservado'));
    expect(provider.errorMessage, isNull);
    // a hora continua até a pessoa decidir
    expect(provider.hora, _dez);

    clearInteractions(listarSlots);
    provider.desistirDoLimite();
    await pumpEventQueue();

    expect(provider.limiteEstourado, isNull);
    expect(provider.hora, isNull);
    verify(() => listarSlots(any())).called(1);
  });

  test('horário fechado do negócio não tem "mesmo assim": a mensagem vai '
      'para a tela, a hora sai e a grade vem de novo', () async {
    when(() => criar(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'Esse horário está fechado.',
          code: 'horario_bloqueado',
        ),
      ),
    );
    final provider = montar();
    await provider.carregar();
    provider.selecionarCliente(_ana);
    provider.selecionarServico(_lavagem);
    await pumpEventQueue();
    provider.selecionarHora(_dez);
    clearInteractions(listarSlots);

    await provider.salvar();
    await pumpEventQueue();

    expect(provider.salvo, isFalse);
    expect(provider.limiteEstourado, isNull);
    expect(provider.errorMessage, 'Esse horário está fechado.');
    expect(provider.hora, isNull);
    verify(() => listarSlots(any())).called(1);
  });

  test(
    'dia lotado vira pergunta; receber mesmo assim manda ignorarLimite',
    () async {
      when(() => criar(any())).thenAnswer(
        (_) async => const Left(
          ServerFailure(
            message: 'O dia já está no limite: 8 de 8 atendimentos.',
            code: 'dia_lotado',
          ),
        ),
      );
      final provider = montar();
      await provider.carregar();
      provider.selecionarCliente(_ana);
      provider.selecionarServico(_lavagem);

      await provider.salvar();

      expect(provider.limiteEstourado, contains('8 de 8'));
      expect(provider.salvo, isFalse);
      final primeiro =
          verify(() => criar(captureAny())).captured.single
              as NovoAtendimentoParams;
      expect(primeiro.ignorarLimite, isFalse);

      // desistir do dia lotado não mexe na grade
      clearInteractions(listarSlots);
      provider.desistirDoLimite();
      await pumpEventQueue();
      expect(provider.limiteEstourado, isNull);
      verifyNever(() => listarSlots(any()));

      when(() => criar(any())).thenAnswer((_) async => Right(_criado));
      await provider.salvar(ignorarLimite: true);

      final segundo =
          verify(() => criar(captureAny())).captured.single
              as NovoAtendimentoParams;
      expect(segundo.ignorarLimite, isTrue);
      expect(provider.limiteEstourado, isNull);
      expect(provider.salvo, isTrue);
    },
  );

  test('erro de validação vai para o campo', () async {
    when(() => criar(any())).thenAnswer(
      (_) async => const Left(
        ValidationFailure(
          fields: {
            'objeto': ['Objeto inválido.'],
          },
        ),
      ),
    );
    final provider = montar();
    await provider.carregar();
    provider.selecionarCliente(_ana);
    provider.selecionarServico(_lavagem);

    await provider.salvar();

    expect(provider.erroDoCampo('objeto'), 'Objeto inválido.');
    expect(provider.errorMessage, isNull);
  });

  test('buscarClientes devolve a primeira página', () async {
    final provider = montar();

    expect(await provider.buscarClientes('ana'), [_ana]);
  });
}
