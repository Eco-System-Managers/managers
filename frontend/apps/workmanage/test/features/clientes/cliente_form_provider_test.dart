import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/clientes/domain/entities/cliente.dart';
import 'package:managers/features/clientes/domain/usecases/atualizar_cliente_use_case.dart';
import 'package:managers/features/clientes/domain/usecases/criar_cliente_use_case.dart';
import 'package:managers/features/clientes/domain/usecases/obter_cliente_use_case.dart';
import 'package:managers/features/clientes/presentation/providers/cliente_form_provider.dart';
import 'package:managers/features/empresa/domain/entities/endereco.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_endereco_por_cep_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockObter extends Mock implements ObterClienteUseCase {}

class _MockCriar extends Mock implements CriarClienteUseCase {}

class _MockAtualizar extends Mock implements AtualizarClienteUseCase {}

class _MockBuscarCep extends Mock implements BuscarEnderecoPorCepUseCase {}

const _ana = Cliente(id: 5, nome: 'Ana', telefone: '19999990000');

void main() {
  late _MockObter obter;
  late _MockCriar criar;
  late _MockAtualizar atualizar;
  late _MockBuscarCep buscarCep;

  setUpAll(() => registerFallbackValue(_ana));

  ClienteFormProvider montar(int? id) {
    return ClienteFormProvider(
      id: id,
      obter: obter,
      criar: criar,
      atualizar: atualizar,
      buscarEnderecoPorCep: buscarCep,
    );
  }

  setUp(() {
    obter = _MockObter();
    criar = _MockCriar();
    atualizar = _MockAtualizar();
    buscarCep = _MockBuscarCep();
    when(() => obter(5)).thenAnswer((_) async => const Right(_ana));
  });

  test('novo: fica pronto sem ir à API', () async {
    final provider = montar(null);

    await provider.carregar();

    expect(provider.ehNovo, isTrue);
    expect(provider.carregado, isTrue);
    expect(provider.cliente, isNull);
    verifyNever(() => obter(any()));
  });

  test('novo salva com criar e fecha', () async {
    when(() => criar(any())).thenAnswer(
      (invocation) async => Right(
        (invocation.positionalArguments.single as Cliente).copyWith(id: 9),
      ),
    );
    final provider = montar(null);

    await provider.salvar(const Cliente(nome: 'Bia', telefone: '19988887777'));

    expect(provider.salvo, isTrue);
    expect(provider.cliente?.id, 9);
    verifyNever(() => atualizar(any()));
  });

  test('edição carrega a ficha e salva com atualizar, levando o id', () async {
    when(() => atualizar(any())).thenAnswer(
      (invocation) async =>
          Right(invocation.positionalArguments.single as Cliente),
    );
    final provider = montar(5);
    await provider.carregar();
    expect(provider.cliente, _ana);

    await provider.salvar(
      const Cliente(nome: 'Ana Maria', telefone: '19999990000'),
    );

    final enviado =
        verify(() => atualizar(captureAny())).captured.single as Cliente;
    expect(enviado.id, 5);
    expect(enviado.nome, 'Ana Maria');
    expect(provider.salvo, isTrue);
  });

  test('erro de validação vai para o campo', () async {
    when(() => criar(any())).thenAnswer(
      (_) async => const Left(
        ValidationFailure(
          fields: {
            'cpf': ['CPF já cadastrado para outro cliente.'],
          },
        ),
      ),
    );
    final provider = montar(null);

    await provider.salvar(_ana);

    expect(provider.salvo, isFalse);
    expect(
      provider.erroDoCampo('cpf'),
      'CPF já cadastrado para outro cliente.',
    );
    expect(provider.errorMessage, isNull);

    provider.limparErroDoCampo('cpf');
    expect(provider.erroDoCampo('cpf'), isNull);
  });

  test('buscarCep devolve o endereço achado ou guarda o erro', () async {
    when(() => buscarCep('01001000')).thenAnswer(
      (_) async => const Right(
        Endereco(
          cep: '01001000',
          endereco: 'Praça da Sé',
          cidade: 'São Paulo',
          uf: 'SP',
        ),
      ),
    );
    when(() => buscarCep('00000000')).thenAnswer(
      (_) async => const Left(NotFoundFailure(message: 'CEP não encontrado.')),
    );
    final provider = montar(null);

    final achado = await provider.buscarCep('01001000');
    expect(achado?.endereco, 'Praça da Sé');
    expect(provider.cepErrorMessage, isNull);

    final naoAchado = await provider.buscarCep('00000000');
    expect(naoAchado, isNull);
    expect(provider.cepErrorMessage, 'CEP não encontrado.');
    expect(provider.buscandoCep, isFalse);
  });
}
