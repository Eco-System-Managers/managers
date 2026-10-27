import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/agenda/domain/usecases/agenda_use_cases.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/listar_colaboradores_use_case.dart';

import '../../domain/entities/dashboard_resumo.dart';
import '../../domain/usecases/obter_resumo_use_case.dart';

// os atalhos de período do painel
enum AtalhoPeriodo { hoje, semana, mes, personalizado }

// estado da aba Início (montado em dashboard_provider.dart, na raiz da
// feature): o período e o profissional escolhidos, os números deles e
// quantas cobranças estão pendentes (o use case é da agenda: a API junta
// os dois modos)
class ResumoProvider extends ChangeNotifier {
  ResumoProvider({
    required this._obterResumo,
    required this._listarColaboradores,
    required this._listarPendencias,
    required this.filtraPorProfissional,
    DateTime? hoje,
  }) : _hoje = somenteData(hoje ?? DateTime.now()) {
    _inicio = _hoje;
    _fim = _hoje;
  }

  final ObterResumoUseCase _obterResumo;
  final ListarColaboradoresUseCase _listarColaboradores;
  final ListarPendenciasUseCase _listarPendencias;

  // só o proprietário escolhe o profissional. para o resto a API já devolve
  // os próprios números, então a equipe nem é carregada
  final bool filtraPorProfissional;
  final DateTime _hoje;

  // a equipe ativa, para os chips; null em colaboradorId é todos
  List<Colaborador> _colaboradores = const [];
  int? _colaboradorId;

  AtalhoPeriodo _atalho = AtalhoPeriodo.hoje;
  late DateTime _inicio;
  late DateTime _fim;
  DashboardResumo? _resumo;
  int _pendencias = 0;
  bool _isLoading = false;
  Failure? _erroAoCarregar;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  AtalhoPeriodo get atalho => _atalho;
  List<Colaborador> get colaboradores => _colaboradores;
  int? get colaboradorId => _colaboradorId;
  DateTime get inicio => _inicio;
  DateTime get fim => _fim;
  DashboardResumo? get resumo => _resumo;

  // atendimentos passados sem cobrança; 0 também quando a consulta falhou
  int get pendencias => _pendencias;

  bool get carregado => _resumo != null;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final (result, _, pendencias) = await (
      _obterResumo(
        ResumoParams(inicio: _inicio, fim: _fim, colaboradorId: _colaboradorId),
      ),
      _garantirColaboradores(),
      _listarPendencias(NoParams()),
    ).wait;
    if (_disposed) return;

    result.fold((failure) => _erroAoCarregar = failure, (r) => _resumo = r);
    pendencias.fold((_) {}, (lista) => _pendencias = lista.length);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> filtrarColaborador(int? id) async {
    if (id == _colaboradorId) return;
    _colaboradorId = id;
    await carregar();
  }

  Future<void> _garantirColaboradores() async {
    if (!filtraPorProfissional || _colaboradores.isNotEmpty) return;
    final result = await _listarColaboradores(NoParams());
    // sem a equipe o painel continua útil: só fica sem o filtro
    result.fold((_) {}, (lista) {
      _colaboradores = lista.where((c) => c.ativo).toList();
    });
  }

  // os atalhos: hoje, os últimos 7 dias e o mês atual até hoje
  Future<void> selecionarAtalho(AtalhoPeriodo atalho) async {
    _atalho = atalho;
    switch (atalho) {
      case AtalhoPeriodo.hoje:
        _inicio = _hoje;
        _fim = _hoje;
      case AtalhoPeriodo.semana:
        _inicio = _hoje.subtract(const Duration(days: 6));
        _fim = _hoje;
      case AtalhoPeriodo.mes:
        _inicio = DateTime(_hoje.year, _hoje.month);
        _fim = _hoje;
      case AtalhoPeriodo.personalizado:
        break;
    }
    await carregar();
  }

  Future<void> selecionarIntervalo(DateTime inicio, DateTime fim) async {
    _atalho = AtalhoPeriodo.personalizado;
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
