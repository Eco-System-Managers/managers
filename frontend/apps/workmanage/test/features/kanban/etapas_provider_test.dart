import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/kanban/domain/entities/etapa.dart';
import 'package:managers/features/kanban/domain/usecases/kanban_use_cases.dart';
import 'package:managers/features/kanban/presentation/providers/etapas_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockListar extends Mock implements ListarEtapasUseCase {}

class _MockSalvar extends Mock implements SalvarEtapaUseCase {}

class _MockRemover extends Mock implements RemoverEtapaUseCase {}

class _MockReordenar extends Mock implements ReordenarEtapasUseCase {}

const _etapas = [
  Etapa(id: 1, nome: 'Aguardando', ordem: 0),
  Etapa(id: 2, nome: 'Lavando', ordem: 1),
  Etapa(id: 3, nome: 'Concluído', ordem: 2),
];

void main() {
  late _MockListar listar;
  late _MockSalvar salvar;
  late _MockRemover remover;
  late _MockReordenar reordenar;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(const Etapa(nome: ''));
    registerFallbackValue(<int>[]);
  });

  EtapasProvider montar() => EtapasProvider(
    listar: listar,
    salvar: salvar,
    remover: remover,
    reordenar: reordenar,
  );

  setUp(() {
    listar = _MockListar();
    salvar = _MockSalvar();
    remover = _MockRemover();
    reordenar = _MockReordenar();
    when(() => listar(any())).thenAnswer((_) async => const Right(_etapas));
  });

  test('salvar põe a etapa nova no fim e relê a lista', () async {
    when(() => salvar(any())).thenAnswer(
      (invocation) async => Right(
        (invocation.positionalArguments.single as Etapa).copyWith(id: 4),
      ),
    );
    final provider = montar();
    await provider.carregar();

    await provider.salvar(const Etapa(nome: 'Secando', cor: '#3B82F6'));

    final enviada = verify(() => salvar(captureAny())).captured.single as Etapa;
    expect(enviada.ordem, 3);
    expect(provider.salvo, isTrue);
    verify(() => listar(any())).called(2);
  });

  test('remover com atendimentos vira mensagem; sem, relê', () async {
    when(() => remover(2)).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'Esta etapa tem atendimentos e não pode ser removida.',
          code: 'etapa_com_atendimentos',
        ),
      ),
    );
    when(() => remover(3)).thenAnswer((_) async => const Right(null));
    final provider = montar();
    await provider.carregar();

    await provider.remover(2);
    expect(provider.errorMessage, contains('tem atendimentos'));
    expect(provider.isLoading, isFalse);

    await provider.remover(3);
    expect(provider.errorMessage, isNull);
    verify(() => listar(any())).called(2);
  });

  test('reordenar manda os ids na nova ordem e relê', () async {
    when(() => reordenar(any())).thenAnswer((_) async => const Right(null));
    final provider = montar();
    await provider.carregar();

    await provider.reordenar(0, 2);

    final ids =
        verify(() => reordenar(captureAny())).captured.single as List<int>;
    expect(ids, [2, 3, 1]);
    verify(() => listar(any())).called(2);
  });

  test('erro ao carregar vira erroAoCarregar', () async {
    when(() => listar(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isFalse);
    expect(provider.erroAoCarregar, isA<NetworkFailure>());
  });
}
