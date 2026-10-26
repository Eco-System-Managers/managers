import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/network/dio_client.dart';
import 'package:managers/features/usuarios/usuarios_provider.dart';

import 'data/datasources/financeiro_remote_datasource.dart';
import 'data/repositories/financeiro_repository_impl.dart';
import 'domain/repositories/financeiro_repository.dart';
import 'domain/usecases/financeiro_use_cases.dart';
import 'presentation/providers/caixa_provider.dart';
import 'presentation/providers/saldo_cliente_provider.dart';

// injeção de dependências do financeiro: é o único lugar que conhece as
// implementações. a agenda usa o saldo daqui na cobrança
final financeiroRemoteDataSourceProvider = Provider<FinanceiroRemoteDataSource>(
  (ref) => FinanceiroRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final financeiroRepositoryProvider = Provider<FinanceiroRepository>(
  (ref) =>
      FinanceiroRepositoryImpl(ref.watch(financeiroRemoteDataSourceProvider)),
);

final obterCaixaUseCaseProvider = Provider(
  (ref) => ObterCaixaUseCase(ref.watch(financeiroRepositoryProvider)),
);

final obterSaldoClienteUseCaseProvider = Provider(
  (ref) => ObterSaldoClienteUseCase(ref.watch(financeiroRepositoryProvider)),
);

// estado das telas. o caixa não é autoDispose: trocar de aba e voltar
// mantém o período escolhido
final caixaProvider = Provider<CaixaProvider>((ref) {
  final provider = CaixaProvider(
    obterCaixa: ref.watch(obterCaixaUseCaseProvider),
    listarColaboradores: ref.watch(listarColaboradoresUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

// family: um provider por ficha de cliente aberta
final saldoClienteProvider = Provider.autoDispose
    .family<SaldoClienteProvider, int>((ref, clienteId) {
      final provider = SaldoClienteProvider(
        clienteId: clienteId,
        obterSaldo: ref.watch(obterSaldoClienteUseCaseProvider),
      );
      ref.onDispose(provider.dispose);
      return provider;
    });
