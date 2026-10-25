import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../../domain/entities/dashboard_resumo.dart';
import '../../domain/usecases/obter_resumo_use_case.dart';

// estado do resumo do mês (montado em dashboard_provider.dart, na raiz da
// feature): só leitura, recarregada a cada abertura
class ResumoProvider extends ChangeNotifier {
  ResumoProvider({required this._obterResumo});

  final ObterResumoUseCase _obterResumo;

  DashboardResumo? _resumo;
  bool _isLoading = false;
  Failure? _erroAoCarregar;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  DashboardResumo? get resumo => _resumo;
  bool get carregado => _resumo != null;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final result = await _obterResumo(NoParams());
    if (_disposed) return;

    result.fold((failure) => _erroAoCarregar = failure, (r) => _resumo = r);

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
