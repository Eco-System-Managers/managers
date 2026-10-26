import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/colaborador.dart';
import '../../domain/params/equipe_params.dart';
import '../../domain/usecases/equipe_use_cases.dart';

// estado do cadastro de alguém sem login (montado em usuarios_provider.dart,
// na raiz da feature). quem precisa entrar no app é convidado depois, pela
// ficha
class ColaboradorFormProvider extends ChangeNotifier {
  ColaboradorFormProvider({required this._criar});

  final CriarColaboradorUseCase _criar;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  Colaborador? _criado;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // erro de validação da API, campo a campo (nome, funcao, comissao_percentual)
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  // quem foi criado; a tela fecha quando chega
  Colaborador? get criado => _criado;
  bool get salvo => _criado != null;

  Future<void> salvar(DadosColaborador dados) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    final result = await _criar(dados);
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
    }, (c) => _criado = c);

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
