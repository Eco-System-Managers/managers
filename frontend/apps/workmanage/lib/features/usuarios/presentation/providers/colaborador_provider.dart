import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/colaborador.dart';
import '../../domain/params/equipe_params.dart';
import '../../domain/usecases/equipe_use_cases.dart';

// estado da ficha de um colaborador (montado em usuarios_provider.dart, na
// raiz da feature): a função, ativar/desativar e remover. a API protege o
// proprietário (proprietario_protegido); a tela nem oferece
class ColaboradorProvider extends ChangeNotifier {
  ColaboradorProvider({
    required this.id,
    required this._obter,
    required this._atualizarFuncao,
    required this._alterarAtivo,
    required this._contarPendentes,
    required this._remover,
  });

  final int id;
  final ObterColaboradorUseCase _obter;
  final AtualizarFuncaoUseCase _atualizarFuncao;
  final AlterarAtivoColaboradorUseCase _alterarAtivo;
  final ContarAgendamentosPendentesUseCase _contarPendentes;
  final RemoverColaboradorUseCase _remover;

  Colaborador? _colaborador;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  bool _funcaoSalva = false;
  bool _removido = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  Colaborador? get colaborador => _colaborador;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro de uma ação; a ficha continua
  String? get errorMessage => _errorMessage;

  // erro de validação da API no campo (funcao)
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  // true logo depois de salvar a função: a tela avisa e zera
  bool get funcaoSalva => _funcaoSalva;

  // true depois de remover: a tela fecha
  bool get removido => _removido;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final result = await _obter(id);
    if (_disposed) return;

    result.fold(
      (failure) => _erroAoCarregar = failure,
      (c) => _colaborador = c,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> salvarFuncao(String funcao) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    _funcaoSalva = false;
    notifyListeners();

    final result = await _atualizarFuncao(
      AtualizarFuncaoParams(id: id, funcao: funcao.trim()),
    );
    if (_disposed) return;

    result.fold(
      (failure) {
        if (failure is ValidationFailure && failure.fields.isNotEmpty) {
          _fieldErrors = {
            for (final e in failure.fields.entries)
              if (e.value.isNotEmpty) e.key: e.value.first,
          };
        } else {
          _errorMessage = failure.message;
        }
      },
      (c) {
        _colaborador = c;
        _funcaoSalva = true;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  void limparErroDoCampo(String campo) {
    if (!_fieldErrors.containsKey(campo)) return;
    _fieldErrors = {..._fieldErrors}..remove(campo);
    notifyListeners();
  }

  void avisoDeFuncaoMostrado() => _funcaoSalva = false;

  // desativar responde 204: a ficha vem da API de novo
  Future<void> alterarAtivo(bool ativo) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _alterarAtivo(
      AlterarAtivoColaboradorParams(id: id, ativo: ativo),
    );
    if (_disposed) return;

    await result.fold((failure) async {
      _errorMessage = failure.message;
      _isLoading = false;
      notifyListeners();
    }, (_) => carregar());
  }

  // quantos agendamentos futuros ficariam sem profissional; null quando a
  // consulta falhou (o erro fica em errorMessage)
  Future<int?> contarPendentes() async {
    final result = await _contarPendentes(id);
    if (_disposed) return null;
    return result.fold((failure) {
      _errorMessage = failure.message;
      notifyListeners();
      return null;
    }, (total) => total);
  }

  Future<void> remover() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _remover(id);
    if (_disposed) return;

    result.fold(
      (failure) => _errorMessage = failure.message,
      (_) => _removido = true,
    );

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
