import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/network/dio_client.dart';
import 'package:managers/core/session/sessao_provider.dart';

import 'data/datasources/auth_remote_datasource.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/excluir_conta_use_case.dart';
import 'domain/usecases/login_use_case.dart';
import 'domain/usecases/logout_use_case.dart';
import 'domain/usecases/reset_password_use_case.dart';
import 'domain/usecases/send_recovery_code_use_case.dart';
import 'domain/usecases/verify_recovery_code_use_case.dart';
import 'presentation/providers/excluir_conta_provider.dart';
import 'presentation/providers/login_provider.dart';
import 'presentation/providers/recovery_provider.dart';

// injeção de dependências da auth: é o único lugar que conhece as
// implementações. trocar a implementação é mexer só aqui
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider)),
);

final loginUseCaseProvider = Provider(
  (ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);

final sendRecoveryCodeUseCaseProvider = Provider(
  (ref) => SendRecoveryCodeUseCase(ref.watch(authRepositoryProvider)),
);

final verifyRecoveryCodeUseCaseProvider = Provider(
  (ref) => VerifyRecoveryCodeUseCase(ref.watch(authRepositoryProvider)),
);

final resetPasswordUseCaseProvider = Provider(
  (ref) => ResetPasswordUseCase(ref.watch(authRepositoryProvider)),
);

final logoutUseCaseProvider = Provider(
  (ref) => LogoutUseCase(ref.watch(authRepositoryProvider)),
);

final excluirContaUseCaseProvider = Provider(
  (ref) => ExcluirContaUseCase(ref.watch(authRepositoryProvider)),
);

// estado das telas. autoDispose: ao sair da tela, loading e erro são
// descartados. a instância é a mesma enquanto a tela estiver aberta, mesmo
// que o router redesenhe a rota
final loginProvider = Provider.autoDispose<LoginProvider>((ref) {
  final provider = LoginProvider(
    login: ref.watch(loginUseCaseProvider),
    sessao: ref.watch(sessaoControllerProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

final recoveryProvider = Provider.autoDispose<RecoveryProvider>((ref) {
  final provider = RecoveryProvider(
    sendRecoveryCode: ref.watch(sendRecoveryCodeUseCaseProvider),
    verifyRecoveryCode: ref.watch(verifyRecoveryCodeUseCaseProvider),
    resetPassword: ref.watch(resetPasswordUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

final excluirContaProvider = Provider.autoDispose<ExcluirContaProvider>((ref) {
  final provider = ExcluirContaProvider(
    excluir: ref.watch(excluirContaUseCaseProvider),
    sessao: ref.watch(sessaoControllerProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});
