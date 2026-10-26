import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/colaborador.dart';
import '../../domain/entities/convite.dart';
import '../../domain/params/equipe_params.dart';
import '../../domain/usecases/equipe_use_cases.dart';

// estado de adicionar alguém à equipe (montado em usuarios_provider.dart, na
// raiz da feature): cria a pessoa e, com e-mail, já manda o convite para o
// app. são duas chamadas: se a segunda falhar, a pessoa fica criada e a tela
// só tenta o convite de novo (criadoSemConvite), sem duplicar o cadastro
class ColaboradorFormProvider extends ChangeNotifier {
  ColaboradorFormProvider({required this._criar, required this._convidar});

  final CriarColaboradorUseCase _criar;
  final ConvidarColaboradorUseCase _convidar;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  Colaborador? _criado;
  Convite? _convite;
  bool _concluido = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // erro de validação da API, campo a campo (nome, funcao,
  // comissao_percentual, email)
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  // quem foi criado e o convite enviado
  Colaborador? get criado => _criado;
  Convite? get convite => _convite;

  // a pessoa já está na equipe, mas o convite não saiu: a próxima tentativa
  // só manda o convite
  bool get criadoSemConvite => _criado != null && !_concluido;

  // tudo feito; a tela fecha
  bool get salvo => _concluido;

  Future<void> salvar(DadosColaborador dados, {String email = ''}) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    if (_criado == null) {
      final result = await _criar(dados);
      if (_disposed) return;
      result.fold(_guardarFalha, (c) => _criado = c);
    }

    final criado = _criado;
    if (criado != null) {
      if (email.trim().isEmpty) {
        _concluido = true;
      } else {
        final result = await _convidar(
          ConvidarColaboradorParams(id: criado.id, email: email.trim()),
        );
        if (_disposed) return;
        result.fold(_guardarFalha, (convite) {
          _convite = convite;
          _concluido = true;
        });
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  void _guardarFalha(Failure failure) {
    if (failure is ValidationFailure && failure.fields.isNotEmpty) {
      _fieldErrors = {
        for (final e in failure.fields.entries)
          if (e.value.isNotEmpty) e.key: e.value.first,
      };
    } else {
      _errorMessage = failure.message;
    }
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
