import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/contratos/domain/entities/contrato.dart';
import 'package:managers/features/contratos/domain/usecases/contratos_use_cases.dart';
import 'package:managers/features/contratos/presentation/providers/contratos_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockListar extends Mock implements ListarContratosUseCase {}

final _contrato = Contrato(
  id: 7,
  clienteId: 5,
  clienteNome: 'Ana',
  titulo: 'Contrato',
  corpo: 'x',
  status: StatusContrato.enviado,
  criadoEm: DateTime(2026, 10, 25),
);

void main() {
  late _MockListar listar;

  setUpAll(() => registerFallbackValue(const ListarContratosParams()));

  setUp(() {
    listar = _MockListar();
    when(() => listar(any())).thenAnswer((_) async => Right([_contrato]));
  });

  test('carregar lista tudo; filtrar manda o status', () async {
    final provider = ContratosProvider(listar: listar);

    await provider.carregar();
    expect(provider.contratos, [_contrato]);
    var params =
        verify(() => listar(captureAny())).captured.last
            as ListarContratosParams;
    expect(params.status, isNull);

    await provider.filtrar(StatusContrato.assinado);
    params =
        verify(() => listar(captureAny())).captured.last
            as ListarContratosParams;
    expect(params.status, StatusContrato.assinado);
    expect(provider.status, StatusContrato.assinado);
  });

  test('erro vira erroAoCarregar', () async {
    when(() => listar(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    final provider = ContratosProvider(listar: listar);

    await provider.carregar();

    expect(provider.carregado, isFalse);
    expect(provider.erroAoCarregar, isA<NetworkFailure>());
  });
}
