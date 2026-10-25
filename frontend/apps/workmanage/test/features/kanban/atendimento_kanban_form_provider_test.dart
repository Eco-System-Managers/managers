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
import 'package:mocktail/mocktail.dart';

class _MockListarEtapas extends Mock implements ListarEtapasUseCase {}

class _MockListarServicos extends Mock implements ListarServicosUseCase {}

class _MockListarClientes extends Mock implements ListarClientesUseCase {}

class _MockObterCliente extends Mock implements ObterClienteUseCase {}

class _MockListarSlots extends Mock implements ListarSlotsKanbanUseCase {}

class _MockCriar extends Mock implements CriarAtendimentoKanbanUseCase {}

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

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(const ListarServicosParams());
    registerFallbackValue(const ListarClientesParams());
    registerFallbackValue(_dia);
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

  test('selecionarData limpa a hora e recarrega a grade', () async {
    final provider = montar();
    await provider.carregar();
    provider.selecionarHora(_nove);

    provider.selecionarData(DateTime(2026, 10, 26));
    await pumpEventQueue();

    expect(provider.hora, isNull);
    expect(
      verify(() => listarSlots(captureAny())).captured.last,
      DateTime(2026, 10, 26),
    );
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

  test('hora ocupada: mensagem, hora limpa e grade recarregada', () async {
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
    provider.selecionarHora(_dez);

    await provider.salvar();
    await pumpEventQueue();

    expect(provider.salvo, isFalse);
    expect(provider.errorMessage, contains('já foi reservado'));
    expect(provider.hora, isNull);
    verify(() => listarSlots(any())).called(2);
  });

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
