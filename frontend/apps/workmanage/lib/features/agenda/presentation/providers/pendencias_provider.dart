import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../../domain/entities/pendencia_cobranca.dart';
import '../../domain/usecases/agenda_use_cases.dart';

// estado da lista de atendimentos passados sem cobrança (montado em
// agenda_provider.dart, na raiz da feature)
class PendenciasProvider extends ChangeNotifier {
  PendenciasProvider({required this._listar});

  final ListarPendenciasUseCase _listar;

  List<PendenciaCobranca> _pendencias = const [];
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  List<PendenciaCobranca> get pendencias => _pendencias;
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final result = await _listar(NoParams());
    if (_disposed) return;

    result.fold((failure) => _erroAoCarregar = failure, (lista) {
      _pendencias = lista;
      _carregado = true;
    });

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
