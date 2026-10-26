import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/contratos/domain/entities/modelo_contrato.dart';
import 'package:managers/features/contratos/domain/usecases/modelos_use_cases.dart';
import 'package:managers/features/contratos/presentation/providers/modelo_form_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockObter extends Mock implements ObterModeloUseCase {}

class _MockCriar extends Mock implements CriarModeloUseCase {}

class _MockAtualizar extends Mock implements AtualizarModeloUseCase {}

class _MockAlterarAtivo extends Mock implements AlterarAtivoModeloUseCase {}

const _padrao = ModeloContrato(id: 2, titulo: 'Padrão', corpo: 'Eu, {{x}}.');

void main() {
  late _MockObter obter;
  late _MockCriar criar;
  late _MockAtualizar atualizar;
  late _MockAlterarAtivo alterarAtivo;

  setUpAll(() {
    registerFallbackValue(_padrao);
    registerFallbackValue(const AlterarAtivoModeloParams(id: 0, ativo: false));
  });

  setUp(() {
    obter = _MockObter();
    criar = _MockCriar();
    atualizar = _MockAtualizar();
    alterarAtivo = _MockAlterarAtivo();
  });

  ModeloFormProvider montar(int? id) => ModeloFormProvider(
    id: id,
    obter: obter,
    criar: criar,
    atualizar: atualizar,
    alterarAtivo: alterarAtivo,
  );

  test('novo: carregar não busca nada e salvar cria', () async {
    when(() => criar(any())).thenAnswer((_) async => const Right(_padrao));
    final provider = montar(null);

    await provider.carregar();
    expect(provider.carregado, isTrue);
    verifyNever(() => obter(any()));

    await provider.salvar(const ModeloContrato(titulo: 'Padrão', corpo: 'x'));

    expect(provider.salvo, isTrue);
    verify(() => criar(any())).called(1);
  });

  test('edição: carregar busca o modelo e salvar atualiza com o id', () async {
    when(() => obter(2)).thenAnswer((_) async => const Right(_padrao));
    when(() => atualizar(any())).thenAnswer((_) async => const Right(_padrao));
    final provider = montar(2);

    await provider.carregar();
    expect(provider.modelo, _padrao);

    await provider.salvar(const ModeloContrato(titulo: 'Novo', corpo: 'y'));

    final enviado =
        verify(() => atualizar(captureAny())).captured.single as ModeloContrato;
    expect(enviado.id, 2);
    expect(enviado.titulo, 'Novo');
    expect(provider.salvo, isTrue);
  });

  test('erro de campo da API vai para o campo', () async {
    when(() => criar(any())).thenAnswer(
      (_) async => const Left(
        ValidationFailure(
          message: 'Dados inválidos.',
          fields: {
            'corpo': ['Este campo não pode ser em branco.'],
          },
        ),
      ),
    );
    final provider = montar(null);
    await provider.carregar();

    await provider.salvar(const ModeloContrato(titulo: 'Padrão', corpo: ''));

    expect(provider.salvo, isFalse);
    expect(provider.erroDoCampo('corpo'), 'Este campo não pode ser em branco.');
    provider.limparErroDoCampo('corpo');
    expect(provider.erroDoCampo('corpo'), isNull);
  });

  test('inativar fecha a tela', () async {
    when(() => obter(2)).thenAnswer((_) async => const Right(_padrao));
    when(() => alterarAtivo(any()))
        .thenAnswer((_) async => Right(_padrao.copyWith(ativo: false)));
    final provider = montar(2);
    await provider.carregar();

    await provider.alterarAtivo(false);

    expect(provider.salvo, isTrue);
    expect(provider.modelo?.ativo, isFalse);
  });
}
