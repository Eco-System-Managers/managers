import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao_controller.dart';
import 'package:managers/features/register/domain/params/confirm_param.dart';
import 'package:managers/features/register/domain/usecases/confirm_register_use_case.dart';
import 'package:managers/features/register/domain/usecases/resend_code_use_case.dart';
import 'package:managers/features/register/presentation/providers/verify_email_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_sessao_repository.dart';

class _MockConfirm extends Mock implements ConfirmRegisterUseCase {}

class _MockResend extends Mock implements ResendCodeUseCase {}

void main() {
  late _MockConfirm confirm;
  late _MockResend resend;
  late SessaoController sessao;
  late VerifyEmailProvider provider;

  setUpAll(() {
    registerFallbackValue(ConfirmParam(email: '', code: ''));
  });

  setUp(() {
    confirm = _MockConfirm();
    resend = _MockResend();
    sessao = SessaoController(FakeSessaoRepository());
    provider = VerifyEmailProvider(
      confirmRegister: confirm,
      resendCode: resend,
      sessao: sessao,
    );
  });

  // o provider liga um timer de reenvio ao nascer
  tearDown(() => provider.dispose());

  test('código certo guarda a sessão da empresa recém-criada', () async {
    when(() => confirm(any()))
        .thenAnswer((_) async => const Right(sessaoDeTeste));

    final ok = await provider.confirm(email: 'dono@demo.com', code: '12345678');

    expect(ok, isTrue);
    expect(sessao.atual, sessaoDeTeste);
    final params =
        verify(() => confirm(captureAny())).captured.single as ConfirmParam;
    expect(params.email, 'dono@demo.com');
    expect(params.code, '12345678');
  });

  test('código errado mostra o detail e não cria sessão', () async {
    when(() => confirm(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'Código inválido ou expirado.',
          code: 'codigo_invalido',
        ),
      ),
    );

    final ok = await provider.confirm(email: 'dono@demo.com', code: '1');

    expect(ok, isFalse);
    expect(provider.errorMessage, 'Código inválido ou expirado.');
    expect(sessao.autenticado, isFalse);
  });

  test('reenviar espera o tempo de espera acabar', () async {
    when(() => resend(any())).thenAnswer((_) async => const Right(null));
    expect(provider.secondsLeft, VerifyEmailProvider.resendCooldown);

    await provider.resend('dono@demo.com');

    verifyNever(() => resend(any()));
  });
}
