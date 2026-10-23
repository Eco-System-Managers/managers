import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import 'data/datasources/register_remote_datasource.dart';
import 'data/repositories/register_repository_impl.dart';
import 'domain/repositories/register_repository.dart';
import 'domain/usecases/confirm_register_use_case.dart';
import 'domain/usecases/register_use_case.dart';
import 'domain/usecases/resend_code_use_case.dart';
import 'presentation/view_models/register_view_model.dart';
import 'presentation/view_models/verify_email_view_model.dart';

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

// autoDispose: ao sair da tela o view model (loading/erro) é descartado
final registerViewModelProvider = Provider.autoDispose<RegisterViewModel>((
  ref,
) {
  final viewModel = RegisterViewModel(ref.watch(registerUseCaseProvider));
  ref.onDispose(viewModel.dispose);
  return viewModel;
});

final confirmRegisterUseCaseProvider = Provider(
  (ref) => ConfirmRegisterUseCase(ref.watch(registerRepositoryProvider)),
);

final resendCodeUseCaseProvider = Provider(
  (ref) => ResendCodeUseCase(ref.watch(registerRepositoryProvider)),
);

// autoDispose: ao sair da tela o view model (e o timer do reenvio) é descartado
final verifyEmailViewModelProvider = Provider.autoDispose<VerifyEmailViewModel>(
  (ref) {
    final viewModel = VerifyEmailViewModel(
      ref.watch(confirmRegisterUseCaseProvider),
      ref.watch(resendCodeUseCaseProvider),
    );
    ref.onDispose(viewModel.dispose);
    return viewModel;
  },
);
