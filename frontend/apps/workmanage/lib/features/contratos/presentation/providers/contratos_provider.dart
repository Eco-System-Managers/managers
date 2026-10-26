import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/contrato.dart';
import '../../domain/usecases/contratos_use_cases.dart';

// estado da lista de contratos (montado em contratos_provider.dart, na raiz
// da feature): o filtro de status e a lista. o filtro vai para a API
class ContratosProvider extends ChangeNotifier {
  ContratosProvider({required this._listar});

  final ListarContratosUseCase _listar;

  List<Contrato> _contratos = [];
  StatusContrato? _status;
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  List<Contrato> get contratos => List.unmodifiable(_contratos);

  // null é todos
  StatusContrato? get status => _status;
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final result = await _listar(ListarContratosParams(status: _status));
    if (_disposed) return;

    result.fold((failure) => _erroAoCarregar = failure, (contratos) {
      _contratos = contratos;
      _carregado = true;
    });

    _isLoading = false;
    notifyListeners();
  }

  Future<void> filtrar(StatusContrato? status) async {
    if (status == _status) return;
    _status = status;
    await carregar();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
