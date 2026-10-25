import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/convite.dart';
import '../../domain/params/equipe_params.dart';
import '../../domain/usecases/equipe_use_cases.dart';

// estado do formulário de convite (montado em usuarios_provider.dart, na
// raiz da feature). a API manda o e-mail com o link; o app só cria
class ConviteFormProvider extends ChangeNotifier {
  ConviteFormProvider({required this._criar});

  final CriarConviteUseCase _criar;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  Convite? _convite;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  bool get isLoading => _isLoading;

  // erro que não é de campo (convite_pendente, email_ja_cadastrado)
  String? get errorMessage => _errorMessage;

  // erro de validação da API, campo a campo (nome, email)
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  // o convite criado; a tela fecha quando ele chega
  Convite? get convite => _convite;
  bool get salvo => _convite != null;

  Future<void> salvar({required String nome, required String email}) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    final result = await _criar(
      NovoConviteParams(nome: nome.trim(), email: email.trim()),
    );
    if (_disposed) return;

    result.fold((failure) {
      if (failure is ValidationFailure && failure.fields.isNotEmpty) {
        _fieldErrors = {
          for (final e in failure.fields.entries)
            if (e.value.isNotEmpty) e.key: e.value.first,
        };
      } else {
        _errorMessage = failure.message;
      }
    }, (c) => _convite = c);

    _isLoading = false;
    notifyListeners();
  }

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
