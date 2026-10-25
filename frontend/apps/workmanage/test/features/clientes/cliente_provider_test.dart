import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/clientes/domain/entities/cliente.dart';
import 'package:managers/features/clientes/domain/usecases/obter_cliente_use_case.dart';
import 'package:managers/features/clientes/domain/usecases/remover_cliente_use_case.dart';
import 'package:managers/features/clientes/presentation/providers/cliente_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockObter extends Mock implements ObterClienteUseCase {}

class _MockRemover extends Mock implements RemoverClienteUseCase {}

const _ana = Cliente(id: 5, nome: 'Ana', telefone: '19999990000');

void main() {
  late _MockObter obter;
  late _MockRemover remover;
  late ClienteProvider provider;

  setUp(() {
    obter = _MockObter();
    remover = _MockRemover();
    provider = ClienteProvider(id: 5, obter: obter, remover: remover);
    when(() => obter(5)).thenAnswer((_) async => const Right(_ana));
  });

  test('carrega a ficha', () async {
    await provider.carregar();

    expect(provider.cliente, _ana);
    expect(provider.erroAoCarregar, isNull);
  });

  test('remover fecha a ficha', () async {
    when(() => remover(5)).thenAnswer((_) async => const Right(null));
    await provider.carregar();

    await provider.remover();

    expect(provider.removido, isTrue);
    expect(provider.errorMessage, isNull);
  });

  test('cliente com atendimento não é removido e a API explica', () async {
    when(() => remover(5)).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'Este cliente tem atendimentos registrados e não pode ser removido.',
          code: 'cliente_com_atendimentos',
        ),
      ),
    );
    await provider.carregar();

    await provider.remover();

    expect(provider.removido, isFalse);
    expect(provider.errorMessage, contains('não pode ser removido'));
    expect(provider.cliente, _ana);
  });

  test('falha ao carregar guarda o erro para tentar de novo', () async {
    when(() => obter(5)).thenAnswer((_) async => const Left(NotFoundFailure()));

    await provider.carregar();

    expect(provider.cliente, isNull);
    expect(provider.erroAoCarregar, isA<NotFoundFailure>());
  });
}
