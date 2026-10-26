import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/listar_colaboradores_use_case.dart';

import '../../domain/entities/caixa.dart';
import '../../domain/usecases/financeiro_use_cases.dart';

// os atalhos de período do caixa
enum PeriodoCaixa { hoje, semana, mes, personalizado }

// estado do fechamento de caixa (montado em financeiro_provider.dart, na
// raiz da feature): o período escolhido e os números dele
class CaixaProvider extends ChangeNotifier {
  CaixaProvider({
    required this._obterCaixa,
    required this._listarColaboradores,
    DateTime? hoje,
  }) : _hoje = somenteData(hoje ?? DateTime.now()) {
    _inicio = _hoje;
    _fim = _hoje;
  }

  final ObterCaixaUseCase _obterCaixa;
  final ListarColaboradoresUseCase _listarColaboradores;
  final DateTime _hoje;

  // a equipe ativa, para o filtro; null em colaboradorId é todos
  List<Colaborador> _colaboradores = const [];
  int? _colaboradorId;

  PeriodoCaixa _periodo = PeriodoCaixa.hoje;
  late DateTime _inicio;
  late DateTime _fim;
  Caixa? _caixa;
  bool _isLoading = false;
  Failure? _erroAoCarregar;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  PeriodoCaixa get periodo => _periodo;
  List<Colaborador> get colaboradores => _colaboradores;
  int? get colaboradorId => _colaboradorId;
  DateTime get inicio => _inicio;
  DateTime get fim => _fim;
  Caixa? get caixa => _caixa;
  bool get carregado => _caixa != null;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final (result, _) = await (
      _obterCaixa(
        CaixaParams(inicio: _inicio, fim: _fim, colaboradorId: _colaboradorId),
      ),
      _garantirColaboradores(),
    ).wait;
    if (_disposed) return;

    result.fold((failure) => _erroAoCarregar = failure, (c) => _caixa = c);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> filtrarColaborador(int? id) async {
    if (id == _colaboradorId) return;
    _colaboradorId = id;
    await carregar();
  }

  Future<void> _garantirColaboradores() async {
    if (_colaboradores.isNotEmpty) return;
    final result = await _listarColaboradores(NoParams());
    // sem a equipe o caixa continua útil: só fica sem o filtro
    result.fold((_) {}, (lista) {
      _colaboradores = lista.where((c) => c.ativo).toList();
    });
  }

  // os atalhos: hoje, os últimos 7 dias e o mês atual até hoje
  Future<void> selecionarPeriodo(PeriodoCaixa periodo) async {
    _periodo = periodo;
    switch (periodo) {
      case PeriodoCaixa.hoje:
        _inicio = _hoje;
        _fim = _hoje;
      case PeriodoCaixa.semana:
        _inicio = _hoje.subtract(const Duration(days: 6));
        _fim = _hoje;
      case PeriodoCaixa.mes:
        _inicio = DateTime(_hoje.year, _hoje.month);
        _fim = _hoje;
      case PeriodoCaixa.personalizado:
        break;
    }
    await carregar();
  }

  Future<void> selecionarIntervalo(DateTime inicio, DateTime fim) async {
    _periodo = PeriodoCaixa.personalizado;
    _inicio = somenteData(inicio);
    _fim = somenteData(fim);
    await carregar();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
