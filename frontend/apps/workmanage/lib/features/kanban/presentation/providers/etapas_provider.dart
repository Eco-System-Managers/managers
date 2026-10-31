import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../../domain/entities/etapa.dart';
// a regra de qual etapa é a de pronto é do domínio; o prefixo evita o choque
// com o getter de mesmo nome
import '../../domain/entities/etapa.dart' as dominio show indiceDePronto;
import '../../domain/usecases/kanban_use_cases.dart';

// estado da tela de etapas do quadro (montado em kanban_provider.dart, na
// raiz da feature): só o proprietário mexe. toda mudança é relida da API
class EtapasProvider extends ChangeNotifier {
  EtapasProvider({
    required this._listar,
    required this._salvar,
    required this._remover,
    required this._reordenar,
    required this._marcarPronto,
  });

  final ListarEtapasUseCase _listar;
  final SalvarEtapaUseCase _salvar;
  final RemoverEtapaUseCase _remover;
  final ReordenarEtapasUseCase _reordenar;
  final MarcarEtapaProntoUseCase _marcarPronto;

  List<Etapa> _etapas = const [];
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  bool _salvo = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  List<Etapa> get etapas => _etapas;
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro de uma ação (etapa_com_atendimentos ou etapa_pronto ao remover)
  String? get errorMessage => _errorMessage;

  // erro de validação da API no campo (nome, cor)
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  // true logo depois de salvar: a folha fecha e zera
  bool get salvo => _salvo;

  // a partir desta posição o atendimento conta como pronto: a etapa
  // marcada ou, sem marcação, a última. -1 sem etapas
  int get indiceDePronto => dominio.indiceDePronto(_etapas);

  // a etapa marcada, ou a última quando nenhuma foi marcada
  bool ehDePronto(Etapa etapa) {
    final indice = indiceDePronto;
    return indice >= 0 && _etapas[indice].id == etapa.id;
  }

  // as etapas depois da de pronto também contam como pronto
  bool ehDepoisDePronto(Etapa etapa) {
    final indice = indiceDePronto;
    final posicao = _etapas.indexWhere((e) => e.id == etapa.id);
    return indice >= 0 && posicao > indice;
  }

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final result = await _listar(NoParams());
    if (_disposed) return;

    result.fold((failure) => _erroAoCarregar = failure, (lista) {
      _etapas = lista;
      _carregado = true;
    });

    _isLoading = false;
    notifyListeners();
  }

  // nova etapa entra no fim; existente mantém a ordem
  Future<void> salvar(Etapa etapa) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    _salvo = false;
    notifyListeners();

    final result = await _salvar(
      etapa.ehNova ? etapa.copyWith(ordem: _etapas.length) : etapa,
    );
    if (_disposed) return;

    await result.fold(
      (failure) async {
        if (failure is ValidationFailure && failure.fields.isNotEmpty) {
          _fieldErrors = {
            for (final e in failure.fields.entries)
              if (e.value.isNotEmpty) e.key: e.value.first,
          };
        } else {
          _errorMessage = failure.message;
        }
        _isLoading = false;
        notifyListeners();
      },
      (_) async {
        _salvo = true;
        await carregar();
      },
    );
  }

  void avisoDeSalvoMostrado() => _salvo = false;

  void limparErroDoCampo(String campo) {
    if (!_fieldErrors.containsKey(campo)) return;
    _fieldErrors = {..._fieldErrors}..remove(campo);
    notifyListeners();
  }

  Future<void> remover(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _remover(id);
    if (_disposed) return;

    await result.fold((failure) async {
      _errorMessage = failure.message;
      _isLoading = false;
      notifyListeners();
    }, (_) => carregar());
  }

  // esta passa a ser a etapa de pronto; a lista é relida com a marca nova
  Future<void> marcarPronto(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _marcarPronto(id);
    if (_disposed) return;

    await result.fold((failure) async {
      _errorMessage = failure.message;
      _isLoading = false;
      notifyListeners();
    }, (_) => carregar());
  }

  // a lista arrastada: manda os ids na nova ordem e relê
  Future<void> reordenar(int de, int para) async {
    final ids = _etapas.map((e) => e.id).toList();
    final id = ids.removeAt(de);
    ids.insert(para, id);

    // a tela já mostra a nova ordem enquanto a API responde
    _etapas = [for (final i in ids) _etapas.firstWhere((e) => e.id == i)];
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _reordenar(ids);
    if (_disposed) return;

    await result.fold((failure) async {
      _errorMessage = failure.message;
      await carregar();
    }, (_) => carregar());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
