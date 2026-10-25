import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/auth/domain/params/reset_password_params.dart';
import 'package:managers/features/auth/domain/params/verify_recovery_code_params.dart';
import 'package:managers/features/auth/domain/usecases/reset_password_use_case.dart';
import 'package:managers/features/auth/domain/usecases/send_recovery_code_use_case.dart';
import 'package:managers/features/auth/domain/usecases/verify_recovery_code_use_case.dart';
import 'package:managers/features/auth/presentation/providers/recovery_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockSend extends Mock implements SendRecoveryCodeUseCase {}

class _MockVerify extends Mock implements VerifyRecoveryCodeUseCase {}

class _MockReset extends Mock implements ResetPasswordUseCase {}

void main() {
  late _MockSend send;
  late _MockVerify verify_;
  late _MockReset reset;
  late RecoveryProvider provider;

  setUpAll(() {
    registerFallbackValue(
      const VerifyRecoveryCodeParams(email: '', codigo: ''),
    );
    registerFallbackValue(
      const ResetPasswordParams(email: '', codigo: '', novaSenha: ''),
    );
  });

  setUp(() {
    send = _MockSend();
    verify_ = _MockVerify();
    reset = _MockReset();
    provider = RecoveryProvider(
      sendRecoveryCode: send,
      verifyRecoveryCode: verify_,
      resetPassword: reset,
    );
    when(() => send(any())).thenAnswer((_) async => const Right(null));
    when(() => verify_(any())).thenAnswer((_) async => const Right(null));
    when(() => reset(any())).thenAnswer((_) async => const Right(null));
  });

  test('o fluxo inteiro leva e-mail e código até a troca de senha', () async {
    await provider.sendCode('  dono@demo.com ');
    expect(provider.step, RecoveryStep.code);
    expect(provider.email, 'dono@demo.com');
    verify(() => send('dono@demo.com')).called(1);

    await provider.verifyCode('12345678');
    expect(provider.step, RecoveryStep.newPassword);
    final verificacao =
        verify(() => verify_(captureAny())).captured.single
            as VerifyRecoveryCodeParams;
    expect(verificacao.email, 'dono@demo.com');
    expect(verificacao.codigo, '12345678');

    await provider.resetPassword('NovaSenha123!');
    expect(provider.step, RecoveryStep.success);
    final troca =
        verify(() => reset(captureAny())).captured.single
            as ResetPasswordParams;
    expect(troca.email, 'dono@demo.com');
    expect(troca.codigo, '12345678');
    expect(troca.novaSenha, 'NovaSenha123!');
  });

  test('código recusado fica na mesma etapa com o detail da API', () async {
    when(() => verify_(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'Código inválido ou expirado.',
          code: 'codigo_invalido',
        ),
      ),
    );
    await provider.sendCode('dono@demo.com');

    await provider.verifyCode('00000000');

    expect(provider.step, RecoveryStep.code);
    expect(provider.errorMessage, 'Código inválido ou expirado.');
  });

  test('reenviar usa o mesmo e-mail e não muda de etapa', () async {
    await provider.sendCode('dono@demo.com');

    await provider.resendCode();

    expect(provider.step, RecoveryStep.code);
    verify(() => send('dono@demo.com')).called(2);
  });

  test('trocar e-mail volta ao começo e limpa o erro', () async {
    await provider.sendCode('dono@demo.com');
    when(() => verify_(any())).thenAnswer(
      (_) async => const Left(ServerFailure(message: 'x', code: 'y')),
    );
    await provider.verifyCode('1');

    provider.backToEmail();

    expect(provider.step, RecoveryStep.email);
    expect(provider.errorMessage, isNull);
  });
}
