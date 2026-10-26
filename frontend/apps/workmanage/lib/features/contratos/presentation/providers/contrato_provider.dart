import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/contrato.dart';
import '../../domain/usecases/contratos_use_cases.dart';

// estado da ficha de um contrato (montado em contratos_provider.dart, na
// raiz da feature): carregar, marcar o status e remover. o estado depois
// de cada ação é o que a API devolveu
class ContratoProvider extends ChangeNotifier {
  ContratoProvider({
    required this.id,
    required this._obter,
    required this._marcar,
    required this._remover,
  });

  final int id;
  final ObterContratoUseCase _obter;
  final MarcarContratoUseCase _marcar;
  final RemoverContratoUseCase _remover;

  Contrato? _contrato;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  bool _removido = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  Contrato? get contrato => _contrato;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro de uma ação (marcar, remover); a ficha continua na tela
  String? get errorMessage => _errorMessage;

  // true depois de remover: a tela fecha
  bool get removido => _removido;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final result = await _obter(id);
    if (_disposed) return;
    result.fold((failure) => _erroAoCarregar = failure, (c) => _contrato = c);

    _isLoading = false;
    notifyListeners();
  }

  // enviado (o PDF foi compartilhado), assinado ou recusado
  Future<bool> marcar(StatusContrato status, {String nomeAssinante = ''}) {
    return _acao(() async {
      final result = await _marcar(
        MarcarContratoParams(
          id: id,
          status: status,
          nomeAssinante: nomeAssinante,
        ),
      );
      return result.fold(
        (failure) {
          _errorMessage = failure.message;
          return false;
        },
        (c) {
          _contrato = c;
          return true;
        },
      );
    });
  }

  Future<bool> remover() {
    return _acao(() async {
      final result = await _remover(id);
      return result.fold((failure) {
        _errorMessage = failure.message;
        return false;
      }, (_) => _removido = true);
    });
  }

  Future<bool> _acao(Future<bool> Function() executar) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final deuCerto = await executar();
    if (_disposed) return deuCerto;

    _isLoading = false;
    notifyListeners();
    return deuCerto;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
