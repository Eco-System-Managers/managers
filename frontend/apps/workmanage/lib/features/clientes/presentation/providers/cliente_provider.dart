import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/cliente.dart';
import '../../domain/usecases/obter_cliente_use_case.dart';
import '../../domain/usecases/remover_cliente_use_case.dart';

// estado da ficha de um cliente (montado em clientes_provider.dart, na raiz
// da feature): carrega da API e remove
class ClienteProvider extends ChangeNotifier {
  ClienteProvider({
    required this.id,
    required this._obter,
    required this._remover,
  });

  final int id;
  final ObterClienteUseCase _obter;
  final RemoverClienteUseCase _remover;

  Cliente? _cliente;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  bool _removido = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  Cliente? get cliente => _cliente;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro da remoção; a ficha continua na tela
  String? get errorMessage => _errorMessage;

  // true depois de remover: a tela fecha
  bool get removido => _removido;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final result = await _obter(id);
    if (_disposed) return;

    result.fold((failure) => _erroAoCarregar = failure, (c) => _cliente = c);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> remover() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _remover(id);
    if (_disposed) return;

    // com atendimento registrado a API recusa (cliente_com_atendimentos);
    // o detail já diz isso para a pessoa
    result.fold(
      (failure) => _errorMessage = failure.message,
      (_) => _removido = true,
    );

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
