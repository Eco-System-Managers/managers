import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao_controller.dart';

import '../../domain/entities/convite.dart';
import '../../domain/params/equipe_params.dart';
import '../../domain/usecases/equipe_use_cases.dart';

// estado da tela de aceite do convite (montado em usuarios_provider.dart,
// na raiz da feature): mostra para quem é o convite, recebe a senha e entra
// com a sessão que a API devolve
class AceitarConviteProvider extends ChangeNotifier {
  AceitarConviteProvider({
    required this.token,
    required this._obterConvite,
    required this._aceitar,
    required this._sessao,
  });

  final String token;
  final ObterConviteUseCase _obterConvite;
  final AceitarConviteUseCase _aceitar;
  final SessaoController _sessao;

  ConviteInfo? _info;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  bool _aceito = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  ConviteInfo? get info => _info;
  bool get isLoading => _isLoading;

  // convite_nao_encontrado, convite_ja_aceito, convite_expirado: a tela
  // mostra o detail e oferece o login
  Failure? get erroAoCarregar => _erroAoCarregar;

  String? get errorMessage => _errorMessage;

  // senha_fraca vem sem fields: fica pendurado no campo da senha
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  // true depois de entrar: a tela vai para a home
  bool get aceito => _aceito;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final result = await _obterConvite(token);
    if (_disposed) return;

    result.fold((failure) => _erroAoCarregar = failure, (i) => _info = i);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> aceitar(String senha) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    final result = await _aceitar(
      AceitarConviteParams(token: token, senha: senha),
    );
    if (_disposed) return;

    final sessao = result.fold((failure) {
      if (failure is ValidationFailure && failure.fields.isNotEmpty) {
        _fieldErrors = {
          for (final e in failure.fields.entries)
            if (e.value.isNotEmpty) e.key: e.value.first,
        };
      } else if (failure.code == 'senha_fraca' ||
          failure.code == 'senha_obrigatoria') {
        _fieldErrors = {'senha': failure.message};
      } else {
        _errorMessage = failure.message;
      }
      return null;
    }, (s) => s);

    if (sessao != null) {
      await _sessao.entrar(sessao);
      if (_disposed) return;
      _aceito = true;
    }

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
