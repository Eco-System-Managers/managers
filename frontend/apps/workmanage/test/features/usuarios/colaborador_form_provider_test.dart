import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/entities/convite.dart';
import 'package:managers/features/usuarios/domain/params/equipe_params.dart';
import 'package:managers/features/usuarios/domain/usecases/equipe_use_cases.dart';
import 'package:managers/features/usuarios/presentation/providers/colaborador_form_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockCriar extends Mock implements CriarColaboradorUseCase {}

class _MockConvidar extends Mock implements ConvidarColaboradorUseCase {}

const _bia = Colaborador(id: 2, nome: 'Bia');

final _convite = Convite(
  id: 5,
  nome: 'Bia',
  email: 'bia@demo.com',
  aceito: false,
  criadoEm: DateTime(2026, 10, 25),
  expiraEm: DateTime(2026, 10, 27),
  colaboradorId: 2,
);

void main() {
  late _MockCriar criar;
  late _MockConvidar convidar;

  setUpAll(() {
    registerFallbackValue(const DadosColaborador(nome: ''));
    registerFallbackValue(const ConvidarColaboradorParams(id: 0, email: ''));
  });

  setUp(() {
    criar = _MockCriar();
    convidar = _MockConvidar();
  });

  test(
    'sem e-mail só cria; com e-mail cria e convida a pessoa criada',
    () async {
      when(() => criar(any())).thenAnswer((_) async => const Right(_bia));
      when(() => convidar(any())).thenAnswer((_) async => Right(_convite));

      final soCria = ColaboradorFormProvider(criar: criar, convidar: convidar);
      await soCria.salvar(const DadosColaborador(nome: 'Bia'));
      expect(soCria.salvo, isTrue);
      expect(soCria.convite, isNull);
      verifyNever(() => convidar(any()));

      final comConvite = ColaboradorFormProvider(
        criar: criar,
        convidar: convidar,
      );
      await comConvite.salvar(
        const DadosColaborador(nome: 'Bia'),
        email: ' bia@demo.com ',
      );
      final params =
          verify(() => convidar(captureAny())).captured.single
              as ConvidarColaboradorParams;
      expect((params.id, params.email), (2, 'bia@demo.com'));
      expect(comConvite.salvo, isTrue);
      expect(comConvite.convite, _convite);
    },
  );

  test('convite falhando deixa a pessoa criada; a próxima tentativa só '
      'convida', () async {
    when(() => criar(any())).thenAnswer((_) async => const Right(_bia));
    when(() => convidar(any())).thenAnswer(
      (_) async => const Left(
        ValidationFailure(
          fields: {
            'email': ['Este e-mail já tem conta.'],
          },
        ),
      ),
    );
    final provider = ColaboradorFormProvider(criar: criar, convidar: convidar);

    await provider.salvar(
      const DadosColaborador(nome: 'Bia'),
      email: 'bia@demo.com',
    );

    expect(provider.salvo, isFalse);
    expect(provider.criadoSemConvite, isTrue);
    expect(provider.erroDoCampo('email'), 'Este e-mail já tem conta.');

    when(() => convidar(any())).thenAnswer((_) async => Right(_convite));
    await provider.salvar(
      const DadosColaborador(nome: 'Bia'),
      email: 'outra@demo.com',
    );

    verify(() => criar(any())).called(1);
    expect(provider.salvo, isTrue);
  });

  test('erro ao criar vai para o campo ou para a mensagem', () async {
    when(() => criar(any())).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'Sem conexão.')),
    );
    final provider = ColaboradorFormProvider(criar: criar, convidar: convidar);

    await provider.salvar(const DadosColaborador(nome: 'Bia'));

    expect(provider.errorMessage, 'Sem conexão.');
    expect(provider.salvo, isFalse);
    expect(provider.criadoSemConvite, isFalse);
  });
}
