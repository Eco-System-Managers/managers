import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/register/domain/params/register_param.dart';
import 'package:managers/features/register/domain/usecases/register_use_case.dart';
import 'package:managers/features/register/presentation/providers/register_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockRegisterUseCase extends Mock implements RegisterUseCase {}

void main() {
  late _MockRegisterUseCase register;
  late RegisterProvider provider;

  setUpAll(() {
    registerFallbackValue(
      RegisterParam(nomeEmpresa: '', nome: '', email: '', senha: ''),
    );
  });

  setUp(() {
    register = _MockRegisterUseCase();
    provider = RegisterProvider(register);
  });

  Future<bool> cadastrar() => provider.register(
    nomeEmpresa: 'Barbearia Central',
    nome: 'Wilson',
    email: 'dono@demo.com',
    senha: 'SenhaForte123!',
  );

  test('cadastro aceito devolve true', () async {
    when(() => register(any())).thenAnswer((_) async => const Right(null));

    expect(await cadastrar(), isTrue);
    expect(provider.errorMessage, isNull);
    final params =
        verify(() => register(captureAny())).captured.single as RegisterParam;
    expect(params.email, 'dono@demo.com');
  });

  test('cadastrar de novo com outro e-mail manda o que recebeu o código; '
      'com o mesmo, não manda', () async {
    when(() => register(any())).thenAnswer((_) async => const Right(null));
    Future<RegisterParam> enviar(String email) async {
      await provider.register(
        nomeEmpresa: 'Barbearia Central',
        nome: 'Wilson',
        email: email,
        senha: 'SenhaForte123!',
      );
      return verify(() => register(captureAny())).captured.single
          as RegisterParam;
    }

    expect((await enviar('dono@errado.com')).emailAnterior, isNull);
    expect((await enviar('dono@demo.com')).emailAnterior, 'dono@errado.com');
    // reenviar o mesmo (com outra caixa) não é troca
    expect((await enviar('Dono@Demo.com')).emailAnterior, isNull);
  });

  test('cadastro recusado não conta como e-mail com código', () async {
    when(() => register(any()))
        .thenAnswer((_) async => const Left(ServerFailure(message: 'Erro')));
    await cadastrar();

    when(() => register(any())).thenAnswer((_) async => const Right(null));
    await provider.register(
      nomeEmpresa: 'Barbearia Central',
      nome: 'Wilson',
      email: 'outro@demo.com',
      senha: 'SenhaForte123!',
    );

    final params =
        verify(() => register(captureAny())).captured.last as RegisterParam;
    expect(params.emailAnterior, isNull);
  });

  test(
    'erro de validação vai para o campo, não para a mensagem geral',
    () async {
      when(() => register(any())).thenAnswer(
        (_) async => const Left(
          ValidationFailure(
            fields: {
              'email': ['Este e-mail já está vinculado a uma conta.'],
            },
          ),
        ),
      );

      expect(await cadastrar(), isFalse);
      expect(
        provider.erroDoCampo('email'),
        'Este e-mail já está vinculado a uma conta.',
      );
      expect(provider.erroDoCampo('nome'), isNull);
      expect(provider.errorMessage, isNull);
    },
  );

  test('mexer no campo limpa o erro que a API apontou nele', () async {
    when(() => register(any())).thenAnswer(
      (_) async => const Left(
        ValidationFailure(
          fields: {
            'email': ['x'],
          },
        ),
      ),
    );
    await cadastrar();

    provider.limparErroDoCampo('email');

    expect(provider.erroDoCampo('email'), isNull);
  });

  test('erro sem campo vira a mensagem geral', () async {
    when(() => register(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));

    expect(await cadastrar(), isFalse);
    expect(provider.errorMessage, 'Não foi possível conectar ao servidor.');
  });
}
