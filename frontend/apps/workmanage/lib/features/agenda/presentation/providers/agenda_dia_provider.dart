import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/empresa/domain/entities/horario_funcionamento.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_horarios_use_case.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/listar_colaboradores_use_case.dart';

import '../../domain/entities/agendamento.dart';
import '../../domain/params/agenda_params.dart';
import '../../domain/usecases/agenda_use_cases.dart';

// estado da agenda do dia (montado em agenda_provider.dart, na raiz da
// feature): o dia escolhido, os agendamentos dele, os dias do mês que têm
// registro (as bolinhas da faixa), o filtro por profissional e quantas
// cobranças estão pendentes
// a grade da agenda: uma linha a cada 15 minutos
const passoDaGrade = 15;

class AgendaDiaProvider extends ChangeNotifier {
  AgendaDiaProvider({
    required this._listarDoDia,
    required this._listarDiasComRegistro,
    required this._listarColaboradores,
    required this._listarPendencias,
    required this._buscarHorarios,
    DateTime? hoje,
  }) : _hoje = somenteData(hoje ?? DateTime.now()),
       _dia = somenteData(hoje ?? DateTime.now());

  final ListarAgendamentosDoDiaUseCase _listarDoDia;
  final ListarDiasComRegistroUseCase _listarDiasComRegistro;
  final ListarColaboradoresUseCase _listarColaboradores;
  final ListarPendenciasUseCase _listarPendencias;
  final BuscarHorariosUseCase _buscarHorarios;

  final DateTime _hoje;
  DateTime _dia;
  List<Agendamento> _agendamentos = const [];
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  int _pendencias = 0;

  // o expediente de cada dia da semana, lido uma vez
  List<HorarioFuncionamento> _horarios = const [];
  bool _horariosCarregados = false;

  // por mês (ano, mês): os dias com registro. um mês só vai à API uma vez
  final Map<(int, int), Set<DateTime>> _meses = {};

  List<Colaborador> _colaboradores = const [];
  int? _colaboradorId;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  DateTime get hoje => _hoje;
  DateTime get dia => _dia;
  bool get ehHoje => mesmoDia(_dia, _hoje);
  List<Agendamento> get agendamentos => _agendamentos;
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // atendimentos passados sem cobrança; 0 também quando a consulta falhou
  int get pendencias => _pendencias;

  // o expediente do dia aberto; null quando o negócio não abre nele (ou
  // enquanto os horários não vieram)
  ({HoraDoDia abertura, HoraDoDia fechamento})? get expedienteDoDia {
    final horario = _horarios
        .where((h) => h.dia.index == _dia.weekday - 1)
        .firstOrNull;
    final abertura = horario?.abertura;
    final fechamento = horario?.fechamento;
    if (horario == null ||
        !horario.ativo ||
        abertura == null ||
        fechamento == null) {
      return null;
    }
    return (abertura: abertura, fechamento: fechamento);
  }

  int get passoMinutos => passoDaGrade;

  // a equipe ativa, para o filtro. vazia enquanto não carregou ou sem equipe
  List<Colaborador> get colaboradores => _colaboradores;

  // null: todos
  int? get colaboradorId => _colaboradorId;

  bool temRegistro(DateTime data) {
    final dias = _meses[(data.year, data.month)];
    return dias != null && dias.contains(somenteData(data));
  }

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final (dia, _, _, _, _) = await (
      _listarDoDia(
        ListarAgendamentosDoDiaParams(
          data: _dia,
          colaboradorId: _colaboradorId,
        ),
      ),
      _garantirMes(_dia),
      _garantirColaboradores(),
      _contarPendencias(),
      _garantirHorarios(),
    ).wait;
    if (_disposed) return;

    dia.fold((failure) => _erroAoCarregar = failure, (lista) {
      _agendamentos = lista;
      _carregado = true;
    });

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

  Future<void> filtrarColaborador(int? id) async {
    if (id == _colaboradorId) return;
    _colaboradorId = id;
    await carregar();
  }

  // a faixa da semana mostra dias de até dois meses: cada um precisa das
  // próprias bolinhas
  Future<void> garantirMesesVisiveis(Iterable<DateTime> dias) async {
    final faltando = {
      for (final d in dias)
        if (!_meses.containsKey((d.year, d.month))) (d.year, d.month),
    };
    if (faltando.isEmpty) return;
    await Future.wait([
      for (final (ano, mes) in faltando) _garantirMes(DateTime(ano, mes)),
    ]);
    if (_disposed) return;
    notifyListeners();
  }

  // ao voltar de uma tela que pode ter criado ou cancelado agendamento, as
  // bolinhas são buscadas de novo
  Future<void> recarregar() async {
    _meses.clear();
    await carregar();
  }

  Future<void> _garantirMes(DateTime data) async {
    final chave = (data.year, data.month);
    if (_meses.containsKey(chave)) return;
    final result = await _listarDiasComRegistro(
      MesParams(ano: data.year, mes: data.month),
    );
    // sem as bolinhas a agenda continua útil: a falha não vira erro da tela
    result.fold((_) {}, (dias) {
      _meses[chave] = {for (final d in dias) somenteData(d)};
    });
  }

  Future<void> _garantirColaboradores() async {
    if (_colaboradores.isNotEmpty) return;
    final result = await _listarColaboradores(NoParams());
    result.fold((_) {}, (lista) {
      _colaboradores = lista.where((c) => c.ativo).toList();
    });
  }

  Future<void> _garantirHorarios() async {
    if (_horariosCarregados) return;
    final result = await _buscarHorarios(NoParams());
    // sem os horários a grade usa o que os agendamentos ocupam
    result.fold((_) {}, (lista) {
      _horarios = lista;
      _horariosCarregados = true;
    });
  }

  Future<void> _contarPendencias() async {
    final result = await _listarPendencias(NoParams());
    result.fold((_) {}, (lista) => _pendencias = lista.length);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
