import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/network/dio_client.dart';
import 'package:managers/core/session/sessao_provider.dart';

import 'data/datasources/register_remote_datasource.dart';
import 'data/repositories/register_repository_impl.dart';
import 'domain/repositories/register_repository.dart';
import 'domain/usecases/confirm_register_use_case.dart';
import 'domain/usecases/register_use_case.dart';
import 'domain/usecases/resend_code_use_case.dart';
import 'presentation/providers/register_provider.dart';
import 'presentation/providers/verify_email_provider.dart';

// injeção de dependências do cadastro: é o único lugar que conhece as
// implementações. trocar a implementação é mexer só aqui
final registerRemoteDataSourceProvider = Provider<RegisterRemoteDataSource>(
  (ref) => RegisterRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final registerRepositoryProvider = Provider<RegisterRepository>(
  (ref) => RegisterRepositoryImpl(ref.watch(registerRemoteDataSourceProvider)),
);

final registerUseCaseProvider = Provider(
  (ref) => RegisterUseCase(ref.watch(registerRepositoryProvider)),
);

final confirmRegisterUseCaseProvider = Provider(
  (ref) => ConfirmRegisterUseCase(ref.watch(registerRepositoryProvider)),
);

final resendCodeUseCaseProvider = Provider(
  (ref) => ResendCodeUseCase(ref.watch(registerRepositoryProvider)),
);

// estado das telas. autoDispose: ao sair da tela, loading e erro são descartados
final registerProvider = Provider.autoDispose<RegisterProvider>((ref) {
  final provider = RegisterProvider(ref.watch(registerUseCaseProvider));
  ref.onDispose(provider.dispose);
  return provider;
});

// autoDispose: ao sair da tela o provider (e o timer do reenvio) é descartado
final verifyEmailProvider = Provider.autoDispose<VerifyEmailProvider>((ref) {
  final provider = VerifyEmailProvider(
    confirmRegister: ref.watch(confirmRegisterUseCaseProvider),
    resendCode: ref.watch(resendCodeUseCaseProvider),
    sessao: ref.watch(sessaoControllerProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});
