import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/params/equipe_params.dart';
import 'package:managers/features/usuarios/domain/usecases/equipe_use_cases.dart';
import 'package:managers/features/usuarios/presentation/providers/colaborador_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockObter extends Mock implements ObterColaboradorUseCase {}

class _MockAtualizarFuncao extends Mock implements AtualizarFuncaoUseCase {}

class _MockAlterarAtivo extends Mock
    implements AlterarAtivoColaboradorUseCase {}

class _MockContarPendentes extends Mock
    implements ContarAgendamentosPendentesUseCase {}

class _MockRemover extends Mock implements RemoverColaboradorUseCase {}

const _bia = Colaborador(id: 2, nome: 'Bia', email: 'bia@demo.com');

void main() {
  late _MockObter obter;
  late _MockAtualizarFuncao atualizarFuncao;
  late _MockAlterarAtivo alterarAtivo;
  late _MockContarPendentes contarPendentes;
  late _MockRemover remover;

  setUpAll(() {
    registerFallbackValue(const AtualizarFuncaoParams(id: 0, funcao: ''));
    registerFallbackValue(
      const AlterarAtivoColaboradorParams(id: 0, ativo: true),
    );
  });

  ColaboradorProvider montar() => ColaboradorProvider(
    id: 2,
    obter: obter,
    atualizarFuncao: atualizarFuncao,
    alterarAtivo: alterarAtivo,
    contarPendentes: contarPendentes,
    remover: remover,
  );

  setUp(() {
    obter = _MockObter();
    atualizarFuncao = _MockAtualizarFuncao();
    alterarAtivo = _MockAlterarAtivo();
    contarPendentes = _MockContarPendentes();
    remover = _MockRemover();
    when(() => obter(2)).thenAnswer((_) async => const Right(_bia));
  });

  test('carregar traz a ficha', () async {
    final provider = montar();

    await provider.carregar();

    expect(provider.colaborador, _bia);
    expect(provider.erroAoCarregar, isNull);
  });

  test('salvarFuncao manda a função sem espaços e avisa; erro de validação '
      'vai para o campo', () async {
    when(() => atualizarFuncao(any())).thenAnswer(
      (_) async => const Right(
        Colaborador(
          id: 2,
          nome: 'Bia',
          email: 'bia@demo.com',
          funcao: 'Barbeira',
        ),
      ),
    );
    final provider = montar();
    await provider.carregar();

    await provider.salvarFuncao('  Barbeira ');

    final params =
        verify(() => atualizarFuncao(captureAny())).captured.single
            as AtualizarFuncaoParams;
    expect(params.id, 2);
    expect(params.funcao, 'Barbeira');
    expect(provider.colaborador?.funcao, 'Barbeira');
    expect(provider.funcaoSalva, isTrue);

    when(() => atualizarFuncao(any())).thenAnswer(
      (_) async => const Left(
        ValidationFailure(
          fields: {
            'funcao': ['No máximo 100 caracteres.'],
          },
        ),
      ),
    );
    await provider.salvarFuncao('x');

    expect(provider.erroDoCampo('funcao'), 'No máximo 100 caracteres.');
    expect(provider.funcaoSalva, isFalse);
  });

  test('alterarAtivo recarrega a ficha; a API protegendo o dono vira '
      'mensagem', () async {
    when(() => alterarAtivo(any())).thenAnswer((_) async => const Right(null));
    final provider = montar();
    await provider.carregar();

    await provider.alterarAtivo(false);

    final params =
        verify(() => alterarAtivo(captureAny())).captured.single
            as AlterarAtivoColaboradorParams;
    expect(params.ativo, isFalse);
    verify(() => obter(2)).called(2);

    when(() => alterarAtivo(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'O proprietário não pode ser desativado nem removido.',
          code: 'proprietario_protegido',
        ),
      ),
    );
    await provider.alterarAtivo(false);

    expect(provider.errorMessage, contains('proprietário'));
    expect(provider.isLoading, isFalse);
  });

  test('contarPendentes devolve o total; erro vira null e mensagem', () async {
    when(() => contarPendentes(2)).thenAnswer((_) async => const Right(3));
    final provider = montar();

    expect(await provider.contarPendentes(), 3);

    when(() => contarPendentes(2))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    expect(await provider.contarPendentes(), isNull);
    expect(provider.errorMessage, isNotNull);
  });

  test('remover fecha a ficha', () async {
    when(() => remover(2)).thenAnswer((_) async => const Right(null));
    final provider = montar();
    await provider.carregar();

    await provider.remover();

    expect(provider.removido, isTrue);
  });
}
