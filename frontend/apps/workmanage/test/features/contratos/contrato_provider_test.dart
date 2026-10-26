import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/contratos/domain/entities/contrato.dart';
import 'package:managers/features/contratos/domain/usecases/contratos_use_cases.dart';
import 'package:managers/features/contratos/presentation/providers/contrato_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockObter extends Mock implements ObterContratoUseCase {}

class _MockMarcar extends Mock implements MarcarContratoUseCase {}

class _MockRemover extends Mock implements RemoverContratoUseCase {}

final _pendente = Contrato(
  id: 7,
  clienteId: 5,
  clienteNome: 'Ana',
  titulo: 'Contrato',
  corpo: 'Eu, Ana, concordo.',
  status: StatusContrato.pendente,
  criadoEm: DateTime(2026, 10, 25, 10),
);

void main() {
  late _MockObter obter;
  late _MockMarcar marcar;
  late _MockRemover remover;

  setUpAll(() {
    registerFallbackValue(
      const MarcarContratoParams(id: 0, status: StatusContrato.enviado),
    );
  });

  setUp(() {
    obter = _MockObter();
    marcar = _MockMarcar();
    remover = _MockRemover();
    when(() => obter(any())).thenAnswer((_) async => Right(_pendente));
  });

  ContratoProvider montar() =>
      ContratoProvider(id: 7, obter: obter, marcar: marcar, remover: remover);

  test('carregar guarda o contrato', () async {
    final provider = montar();

    await provider.carregar();

    expect(provider.contrato, _pendente);
    expect(provider.isLoading, isFalse);
  });

  test('marcar manda status e nome e fica com o que a API devolveu', () async {
    final assinado = Contrato(
      id: 7,
      clienteId: 5,
      clienteNome: 'Ana',
      titulo: 'Contrato',
      corpo: 'Eu, Ana, concordo.',
      status: StatusContrato.assinado,
      nomeAssinante: 'Ana Lima',
      assinadoEm: DateTime(2026, 10, 25, 12),
      criadoEm: DateTime(2026, 10, 25, 10),
    );
    when(() => marcar(any())).thenAnswer((_) async => Right(assinado));
    final provider = montar();
    await provider.carregar();

    final ok = await provider.marcar(
      StatusContrato.assinado,
      nomeAssinante: 'Ana Lima',
    );

    expect(ok, isTrue);
    final params =
        verify(() => marcar(captureAny())).captured.single
            as MarcarContratoParams;
    expect(params.id, 7);
    expect(params.status, StatusContrato.assinado);
    expect(params.nomeAssinante, 'Ana Lima');
    expect(provider.contrato, assinado);
  });

  test('erro ao marcar fica na tela e o contrato não muda', () async {
    when(() => marcar(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(message: 'Já finalizado.', code: 'contrato_finalizado'),
      ),
    );
    final provider = montar();
    await provider.carregar();

    final ok = await provider.marcar(StatusContrato.recusado);

    expect(ok, isFalse);
    expect(provider.errorMessage, 'Já finalizado.');
    expect(provider.contrato, _pendente);
  });

  test('remover marca removido', () async {
    when(() => remover(7)).thenAnswer((_) async => const Right(null));
    final provider = montar();

    expect(await provider.remover(), isTrue);
    expect(provider.removido, isTrue);
  });
}
