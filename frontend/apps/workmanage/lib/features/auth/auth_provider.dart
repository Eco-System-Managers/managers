import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/login_use_case.dart';
import 'domain/usecases/reset_password_use_case.dart';
import 'domain/usecases/send_recovery_code_use_case.dart';
import 'domain/usecases/verify_recovery_code_use_case.dart';

// injeção de dependências da auth: é o único lugar que conhece a
// implementação do repository. trocar a implementação é mexer só aqui
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(),
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
