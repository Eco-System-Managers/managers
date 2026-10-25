import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/utils/lista_paginada.dart';
import 'package:managers/features/clientes/domain/entities/cliente.dart';
import 'package:managers/features/clientes/domain/params/listar_clientes_params.dart';
import 'package:managers/features/clientes/domain/usecases/listar_clientes_use_case.dart';
import 'package:managers/features/clientes/presentation/providers/clientes_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockListar extends Mock implements ListarClientesUseCase {}

Cliente _cliente(int id) =>
    Cliente(id: id, nome: 'Cliente $id', telefone: '1999999000$id');

ListaPaginada<Cliente> _pagina(List<int> ids, {required bool temMais}) {
  return ListaPaginada(
    itens: ids.map(_cliente).toList(),
    total: 45,
    temMais: temMais,
  );
}

void main() {
  late _MockListar listar;
  late ClientesProvider provider;

  setUpAll(() => registerFallbackValue(const ListarClientesParams()));

  setUp(() {
    listar = _MockListar();
    provider = ClientesProvider(listar: listar);
  });

  test('carregar traz a primeira página', () async {
    when(() => listar(any()))
        .thenAnswer((_) async => Right(_pagina([1, 2], temMais: true)));

    await provider.carregar();

    final params =
        verify(() => listar(captureAny())).captured.single
            as ListarClientesParams;
    expect(params.pagina, 1);
    expect(params.busca, isNull);
    expect(provider.clientes.map((c) => c.id), [1, 2]);
    expect(provider.total, 45);
    expect(provider.temMais, isTrue);
    expect(provider.carregado, isTrue);
  });

  test('carregarMais acrescenta a página seguinte e para no fim', () async {
    when(() => listar(any())).thenAnswer((invocation) async {
      final params =
          invocation.positionalArguments.single as ListarClientesParams;
      return Right(
        params.pagina == 1
            ? _pagina([1, 2], temMais: true)
            : _pagina([3], temMais: false),
      );
    });
    await provider.carregar();

    await provider.carregarMais();
    expect(provider.clientes.map((c) => c.id), [1, 2, 3]);
    expect(provider.temMais, isFalse);

    // sem mais páginas, não vai à API
    await provider.carregarMais();
    verify(() => listar(any())).called(2);
  });

  test('buscar recomeça da primeira página com o texto', () async {
    when(() => listar(any()))
        .thenAnswer((_) async => Right(_pagina([7], temMais: false)));

    await provider.buscar(' ana ');

    final params =
        verify(() => listar(captureAny())).captured.single
            as ListarClientesParams;
    expect(params.pagina, 1);
    expect(params.busca, 'ana');
    expect(provider.busca, 'ana');
  });

  test('erro na próxima página fica no rodapé, com a lista intacta', () async {
    when(() => listar(any())).thenAnswer((invocation) async {
      final params =
          invocation.positionalArguments.single as ListarClientesParams;
      return params.pagina == 1
          ? Right(_pagina([1], temMais: true))
          : const Left(NetworkFailure());
    });
    await provider.carregar();

    await provider.carregarMais();

    expect(provider.clientes.length, 1);
    expect(provider.errorMessage, 'Não foi possível conectar ao servidor.');
    expect(provider.carregandoMais, isFalse);
  });

  test('falha na primeira página guarda o erro da tela', () async {
    when(() => listar(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));

    await provider.carregar();

    expect(provider.carregado, isFalse);
    expect(provider.erroAoCarregar, isA<NetworkFailure>());
  });
}
