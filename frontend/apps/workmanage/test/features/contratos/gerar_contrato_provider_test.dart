import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/utils/lista_paginada.dart';
import 'package:managers/features/clientes/domain/entities/cliente.dart';
import 'package:managers/features/clientes/domain/params/listar_clientes_params.dart';
import 'package:managers/features/clientes/domain/usecases/listar_clientes_use_case.dart';
import 'package:managers/features/clientes/domain/usecases/obter_cliente_use_case.dart';
import 'package:managers/features/contratos/domain/entities/contrato.dart';
import 'package:managers/features/contratos/domain/entities/modelo_contrato.dart';
import 'package:managers/features/contratos/domain/usecases/contratos_use_cases.dart';
import 'package:managers/features/contratos/domain/usecases/modelos_use_cases.dart';
import 'package:managers/features/contratos/presentation/providers/gerar_contrato_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockListarModelos extends Mock implements ListarModelosUseCase {}

class _MockListarClientes extends Mock implements ListarClientesUseCase {}

class _MockObterCliente extends Mock implements ObterClienteUseCase {}

class _MockGerar extends Mock implements GerarContratoUseCase {}

const _padrao = ModeloContrato(id: 2, titulo: 'Padrão', corpo: 'x');
const _outro = ModeloContrato(id: 3, titulo: 'Outro', corpo: 'y');
const _ana = Cliente(id: 5, nome: 'Ana', telefone: '11999990000');

final _gerado = Contrato(
  id: 7,
  modeloId: 2,
  clienteId: 5,
  clienteNome: 'Ana',
  titulo: 'Padrão',
  corpo: 'x',
  status: StatusContrato.pendente,
  criadoEm: DateTime(2026, 10, 25),
);

void main() {
  late _MockListarModelos listarModelos;
  late _MockListarClientes listarClientes;
  late _MockObterCliente obterCliente;
  late _MockGerar gerar;

  setUpAll(() {
    registerFallbackValue(const ListarModelosParams());
    registerFallbackValue(const ListarClientesParams());
    registerFallbackValue(const GerarContratoParams(modeloId: 0, clienteId: 0));
  });

  setUp(() {
    listarModelos = _MockListarModelos();
    listarClientes = _MockListarClientes();
    obterCliente = _MockObterCliente();
    gerar = _MockGerar();
    when(() => listarModelos(any()))
        .thenAnswer((_) async => const Right([_padrao, _outro]));
    when(() => obterCliente(5)).thenAnswer((_) async => const Right(_ana));
    when(() => gerar(any())).thenAnswer((_) async => Right(_gerado));
  });

  GerarContratoProvider montar({int? clienteId}) => GerarContratoProvider(
    clienteInicialId: clienteId,
    listarModelos: listarModelos,
    listarClientes: listarClientes,
    obterCliente: obterCliente,
    gerar: gerar,
  );

  test('carregar pede só os modelos ativos e o cliente que já veio', () async {
    final provider = montar(clienteId: 5);

    await provider.carregar();

    final params =
        verify(() => listarModelos(captureAny())).captured.single
            as ListarModelosParams;
    expect(params.ativo, isTrue);
    expect(provider.modelos, [_padrao, _outro]);
    expect(provider.cliente, _ana);
    // com dois modelos, ninguém escolhido ainda
    expect(provider.modelo, isNull);
  });

  test(
    'um modelo só já vem escolhido; sem cliente inicial não busca',
    () async {
      when(() => listarModelos(any()))
          .thenAnswer((_) async => const Right([_padrao]));
      final provider = montar();

      await provider.carregar();

      expect(provider.modelo, _padrao);
      expect(provider.cliente, isNull);
      verifyNever(() => obterCliente(any()));
    },
  );

  test('gerar sem escolher aponta os campos e não chama a API', () async {
    final provider = montar();
    await provider.carregar();

    await provider.gerar();

    expect(provider.erroDoCampo('modelo'), isNotNull);
    expect(provider.erroDoCampo('cliente'), isNotNull);
    verifyNever(() => gerar(any()));
  });

  test('gerar manda modelo e cliente e guarda o contrato criado', () async {
    final provider = montar(clienteId: 5);
    await provider.carregar();
    provider.selecionarModelo(_outro);

    await provider.gerar();

    final params =
        verify(() => gerar(captureAny())).captured.single
            as GerarContratoParams;
    expect((params.modeloId, params.clienteId), (3, 5));
    expect(provider.gerado, _gerado);
  });

  test(
    'buscarClientes devolve os itens da página; erro vira lista vazia',
    () async {
      when(() => listarClientes(any())).thenAnswer(
        (_) async =>
            const Right(ListaPaginada(itens: [_ana], total: 1, temMais: false)),
      );
      final provider = montar();

      expect(await provider.buscarClientes('an'), [_ana]);

      when(() => listarClientes(any()))
          .thenAnswer((_) async => const Left(NetworkFailure()));
      expect(await provider.buscarClientes('an'), isEmpty);
    },
  );
}
