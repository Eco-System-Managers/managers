import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/contrato.dart';
import '../../domain/usecases/contratos_use_cases.dart';

// os contratos de um cliente, para o cartão da ficha dele (montado em
// contratos_provider.dart, na raiz da feature)
class ContratosClienteProvider extends ChangeNotifier {
  ContratosClienteProvider({required this.clienteId, required this._listar});

  final int clienteId;
  final ListarContratosUseCase _listar;

  List<Contrato> _contratos = [];
  bool _carregado = false;
  Failure? _erro;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  List<Contrato> get contratos => List.unmodifiable(_contratos);
  bool get carregado => _carregado;
  Failure? get erro => _erro;

  Future<void> carregar() async {
    _erro = null;
    notifyListeners();

    final result = await _listar(ListarContratosParams(clienteId: clienteId));
    if (_disposed) return;

    result.fold((failure) => _erro = failure, (contratos) {
      _contratos = contratos;
      _carregado = true;
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
