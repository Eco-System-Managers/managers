import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/params/register_param.dart';
import '../../domain/usecases/register_use_case.dart';

// estado da tela de cadastro: recebe o use case pelo construtor
// (montado em register_provider.dart, na raiz da feature)
class RegisterProvider extends ChangeNotifier {
  RegisterProvider(this._registerUseCase);

  final RegisterUseCase _registerUseCase;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // mensagem da última falha que não é de campo (null quando não houve erro)
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // erro de validação da API, campo a campo: a tela mostra embaixo do
  // campo certo, não num aviso genérico
  Map<String, String> _fieldErrors = const {};
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  // o e-mail que recebeu o último código. a tela de cadastro fica viva por
  // baixo da verificação: voltando pelo "Trocar e-mail" e mandando outro, o
  // pendente deste é descartado na API. só em memória, como o formulário
  String? _emailComCodigo;

  // a tela pode ser fechada durante a requisição
  bool _disposed = false;

  // ação chamada pela tela: devolve true se o cadastro deu certo
  Future<bool> register({
    required String nomeEmpresa,
    required String nome,
    required String email,
    required String senha,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    final anterior = _emailComCodigo;
    final params = RegisterParam(
      nomeEmpresa: nomeEmpresa,
      nome: nome,
      email: email,
      senha: senha,
      emailAnterior: anterior != null && !_mesmoEmail(anterior, email)
          ? anterior
          : null,
    );

    final result = await _registerUseCase(params);

    if (_disposed) return false;

    _isLoading = false;

    final success = result.fold(
      (failure) {
        if (failure is ValidationFailure && failure.fields.isNotEmpty) {
          _fieldErrors = {
            for (final e in failure.fields.entries)
              if (e.value.isNotEmpty) e.key: e.value.first,
          };
        } else {
          _errorMessage = failure.message;
        }
        return false;
      },
      (_) {
        _emailComCodigo = email;
        return true;
      },
    );

    notifyListeners();
    return success;
  }

  // a API guarda o e-mail em minúsculas e sem espaços nas pontas
  static bool _mesmoEmail(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  // a pessoa mexeu no campo: o erro que a API apontou nele não vale mais
  void limparErroDoCampo(String campo) {
    if (!_fieldErrors.containsKey(campo)) return;
    _fieldErrors = {..._fieldErrors}..remove(campo);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
