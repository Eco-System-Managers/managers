import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/usuarios/domain/entities/convite.dart';
import 'package:managers/features/usuarios/domain/params/equipe_params.dart';
import 'package:managers/features/usuarios/domain/usecases/equipe_use_cases.dart';
import 'package:managers/features/usuarios/presentation/providers/convite_form_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockCriar extends Mock implements CriarConviteUseCase {}

final _convite = Convite(
  id: 5,
  nome: 'Caio',
  email: 'caio@demo.com',
  aceito: false,
  criadoEm: DateTime(2026, 10, 25),
  expiraEm: DateTime(2026, 10, 27),
);

void main() {
  late _MockCriar criar;

  setUpAll(() {
    registerFallbackValue(const NovoConviteParams(nome: '', email: ''));
  });

  setUp(() => criar = _MockCriar());

  test('salvar manda nome e e-mail sem espaços e fecha', () async {
    when(() => criar(any())).thenAnswer((_) async => Right(_convite));
    final provider = ConviteFormProvider(criar: criar);

    await provider.salvar(nome: ' Caio ', email: ' caio@demo.com ');

    final params =
        verify(() => criar(captureAny())).captured.single as NovoConviteParams;
    expect(params.nome, 'Caio');
    expect(params.email, 'caio@demo.com');
    expect(provider.salvo, isTrue);
    expect(provider.convite, _convite);
  });

  test('regra de negócio vira mensagem; validação vai para o campo', () async {
    when(() => criar(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'Já existe um convite pendente para este e-mail.',
          code: 'convite_pendente',
        ),
      ),
    );
    final provider = ConviteFormProvider(criar: criar);

    await provider.salvar(nome: '', email: 'caio@demo.com');

    expect(provider.salvo, isFalse);
    expect(provider.errorMessage, contains('convite pendente'));

    when(() => criar(any())).thenAnswer(
      (_) async => const Left(
        ValidationFailure(
          fields: {
            'email': ['Insira um endereço de email válido.'],
          },
        ),
      ),
    );
    await provider.salvar(nome: '', email: 'caio');

    expect(provider.errorMessage, isNull);
    expect(provider.erroDoCampo('email'), contains('email válido'));

    provider.limparErroDoCampo('email');
    expect(provider.erroDoCampo('email'), isNull);
  });
}
