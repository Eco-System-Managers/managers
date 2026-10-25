import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/saldo_cliente.dart';
import '../../domain/usecases/financeiro_use_cases.dart';

// estado do crédito de um cliente, para a ficha dele (montado em
// financeiro_provider.dart, na raiz da feature)
class SaldoClienteProvider extends ChangeNotifier {
  SaldoClienteProvider({required this.clienteId, required this._obterSaldo});

  final int clienteId;
  final ObterSaldoClienteUseCase _obterSaldo;

  SaldoCliente? _saldo;
  bool _isLoading = false;
  Failure? _erro;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  SaldoCliente? get saldo => _saldo;
  bool get isLoading => _isLoading;
  Failure? get erro => _erro;

  Future<void> carregar() async {
    _isLoading = true;
    _erro = null;
    notifyListeners();

    final result = await _obterSaldo(clienteId);
    if (_disposed) return;

    result.fold((failure) => _erro = failure, (s) => _saldo = s);

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
