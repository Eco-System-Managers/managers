import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/modelo_contrato.dart';
import '../../domain/usecases/modelos_use_cases.dart';

// estado do formulário de modelo (montado em contratos_provider.dart, na
// raiz da feature): novo quando o id é null, edição quando não é
class ModeloFormProvider extends ChangeNotifier {
  ModeloFormProvider({
    required this.id,
    required this._obter,
    required this._criar,
    required this._atualizar,
    required this._alterarAtivo,
  });

  // null = modelo novo
  final int? id;

  final ObterModeloUseCase _obter;
  final CriarModeloUseCase _criar;
  final AtualizarModeloUseCase _atualizar;
  final AlterarAtivoModeloUseCase _alterarAtivo;

  ModeloContrato? _modelo;
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  bool _salvo = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  bool get ehNovo => id == null;

  // null enquanto carrega ou quando é novo
  ModeloContrato? get modelo => _modelo;
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro que não é de campo (rede, permissão, regra sem campo)
  String? get errorMessage => _errorMessage;

  // erro de validação da API, campo a campo (titulo, corpo)
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  // true depois de salvar ou inativar: a tela fecha
  bool get salvo => _salvo;

  Future<void> carregar() async {
    final id = this.id;
    if (id == null) {
      _carregado = true;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final result = await _obter(id);
    if (_disposed) return;
    result.fold((failure) => _erroAoCarregar = failure, (m) => _modelo = m);

    _carregado = _erroAoCarregar == null;
    _isLoading = false;
    notifyListeners();
  }

  // a tela entrega o modelo montado a partir dos campos, já validados
  Future<void> salvar(ModeloContrato dados) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    final id = this.id;
    final result = id == null
        ? await _criar(dados)
        : await _atualizar(dados.copyWith(id: id));
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
      (salvo) {
        _modelo = salvo;
        _salvo = true;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  // a pessoa mexeu no campo: o erro que a API apontou nele não vale mais
  void limparErroDoCampo(String campo) {
    if (!_fieldErrors.containsKey(campo)) return;
    _fieldErrors = {..._fieldErrors}..remove(campo);
    notifyListeners();
  }

  // inativar ou reativar o modelo aberto; a tela fecha e a lista recarrega
  Future<void> alterarAtivo(bool ativo) async {
    final id = this.id;
    if (id == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _alterarAtivo(
      AlterarAtivoModeloParams(id: id, ativo: ativo),
    );
    if (_disposed) return;

    result.fold((failure) => _errorMessage = failure.message, (salvo) {
      _modelo = salvo;
      _salvo = true;
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
