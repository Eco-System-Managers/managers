import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/agenda/domain/usecases/agenda_use_cases.dart'
    show ListarPendenciasUseCase;

import '../../domain/entities/atendimento_kanban.dart';
import '../../domain/entities/etapa.dart';
import '../../domain/params/kanban_params.dart';
import '../../domain/usecases/kanban_use_cases.dart';

// estado do quadro (montado em kanban_provider.dart, na raiz da feature): o
// dia escolhido, as etapas e os cards de cada uma, e quantas cobranças
// estão pendentes (as pendências são as mesmas da agenda: a API junta os
// dois modos)
class QuadroProvider extends ChangeNotifier {
  QuadroProvider({
    required this._listarEtapas,
    required this._listarDoDia,
    required this._mover,
    required this._listarPendencias,
    DateTime? hoje,
  }) : _hoje = somenteData(hoje ?? DateTime.now()),
       _dia = somenteData(hoje ?? DateTime.now());

  final ListarEtapasUseCase _listarEtapas;
  final ListarAtendimentosDoDiaUseCase _listarDoDia;
  final MoverAtendimentoUseCase _mover;
  final ListarPendenciasUseCase _listarPendencias;

  final DateTime _hoje;
  DateTime _dia;
  List<Etapa> _etapas = const [];
  List<AtendimentoKanban> _atendimentos = const [];
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  int _pendencias = 0;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  DateTime get hoje => _hoje;
  DateTime get dia => _dia;
  bool get ehHoje => mesmoDia(_dia, _hoje);
  List<Etapa> get etapas => _etapas;
  List<AtendimentoKanban> get atendimentos => _atendimentos;
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro de uma ação (mover); o quadro continua
  String? get errorMessage => _errorMessage;

  // atendimentos passados sem cobrança; 0 também quando a consulta falhou
  int get pendencias => _pendencias;

  // os cards de uma coluna: quem tem hora marcada primeiro, na ordem da
  // hora; depois os sem hora, na ordem de chegada
  List<AtendimentoKanban> naEtapa(int etapaId) {
    final cards = _atendimentos.where((a) => a.etapaId == etapaId).toList();
    cards.sort((a, b) {
      final ha = a.horarioEntrada;
      final hb = b.horarioEntrada;
      if (ha != null && hb != null) {
        final porHora = (ha.hora * 60 + ha.minuto).compareTo(
          hb.hora * 60 + hb.minuto,
        );
        if (porHora != 0) return porHora;
      } else if (ha != null) {
        return -1;
      } else if (hb != null) {
        return 1;
      }
      return a.id.compareTo(b.id);
    });
    return cards;
  }

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final (etapas, dia, pendencias) = await (
      _listarEtapas(NoParams()),
      _listarDoDia(_dia),
      _listarPendencias(NoParams()),
    ).wait;
    if (_disposed) return;

    etapas.fold((failure) => _erroAoCarregar = failure, (lista) {
      _etapas = lista;
    });
    dia.fold((failure) => _erroAoCarregar ??= failure, (lista) {
      _atendimentos = lista;
    });
    if (_erroAoCarregar == null) _carregado = true;
    pendencias.fold((_) {}, (lista) => _pendencias = lista.length);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> selecionarDia(DateTime data) async {
    final novo = somenteData(data);
    if (mesmoDia(novo, _dia)) return;
    _dia = novo;
    notifyListeners();
    await carregar();
  }

  Future<void> irParaHoje() => selecionarDia(_hoje);

  // ao voltar de uma tela que pode ter mudado o quadro
  Future<void> recarregar() => carregar();

  // o card muda de coluna e o quadro é relido da API
  Future<void> mover(int id, int etapaId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _mover(
      MoverAtendimentoParams(id: id, etapaId: etapaId),
    );
    if (_disposed) return;

    await result.fold((failure) async {
      _errorMessage = failure.message;
      _isLoading = false;
      notifyListeners();
    }, (_) => carregar());
  }

  void limparErro() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
