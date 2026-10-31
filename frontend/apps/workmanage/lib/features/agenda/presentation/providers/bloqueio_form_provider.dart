import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/listar_colaboradores_use_case.dart';

import '../../domain/entities/bloqueio.dart';
import '../../domain/params/agenda_params.dart';
import '../../domain/usecases/agenda_use_cases.dart';

// estado do formulário de bloqueio (montado em agenda_provider.dart, na raiz
// da feature): de quem, o período (um dia, uma semana, um mês ou fixo), o
// início e a faixa de horário ou o dia inteiro. começa no almoço, 12h às 13h,
// o bloqueio mais comum. no modo do negócio (a esteira) não há profissional:
// o período fecha para marcar no negócio inteiro
class BloqueioFormProvider extends ChangeNotifier {
  BloqueioFormProvider({
    required this._listarColaboradores,
    required this._criar,
    this.somenteColaboradorId,
    this.colaboradorInicialId,
    this.doNegocio = false,
    DateTime? dataInicial,
    DateTime? hoje,
  }) : _hoje = somenteData(hoje ?? DateTime.now()),
       _dataInicio = somenteData(dataInicial ?? hoje ?? DateTime.now()) {
    // aberto de um dia que já passou: o bloqueio começa hoje
    if (_dataInicio.isBefore(_hoje)) _dataInicio = _hoje;
  }

  final ListarColaboradoresUseCase _listarColaboradores;
  final CriarBloqueioUseCase _criar;

  // o parceiro só bloqueia a própria agenda: com isso, o profissional fica
  // fixo nele. null para o dono, que escolhe
  final int? somenteColaboradorId;
  final int? colaboradorInicialId;

  // o bloqueio do negócio inteiro, sem profissional (só o proprietário, e
  // quem monta o provider já conferiu). a equipe nem é carregada
  final bool doNegocio;

  final DateTime _hoje;

  List<Colaborador> _colaboradores = const [];
  bool _carregado = false;
  Failure? _erroAoCarregar;

  Colaborador? _colaborador;
  PeriodoDoBloqueio _periodo = PeriodoDoBloqueio.umDia;
  DateTime _dataInicio;
  bool _diaInteiro = false;
  Hora _horaInicio = (hora: 12, minuto: 0);
  Hora _horaFim = (hora: 13, minuto: 0);

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  Bloqueio? _criado;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  bool get carregado => _carregado;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // a equipe ativa; para o parceiro, só ele
  List<Colaborador> get colaboradores => _colaboradores;
  bool get colaboradorFixo => somenteColaboradorId != null;

  Colaborador? get colaborador => _colaborador;
  PeriodoDoBloqueio get periodo => _periodo;
  DateTime get dataInicio => _dataInicio;
  DateTime? get dataFim => fimDoPeriodo(_periodo, _dataInicio);
  bool get diaInteiro => _diaInteiro;
  Hora get horaInicio => _horaInicio;
  Hora get horaFim => _horaFim;

  // o bloqueio começa hoje ou depois
  DateTime get hoje => _hoje;

  // a faixa precisa terminar depois de começar
  bool get horarioValido =>
      _diaInteiro ||
      _horaFim.hora * 60 + _horaFim.minuto >
          _horaInicio.hora * 60 + _horaInicio.minuto;

  bool get isLoading => _isLoading;

  // erro que não é de campo (rede, cliente marcado no período)
  String? get errorMessage => _errorMessage;

  // erro de validação da API, campo a campo, com os nomes do contrato
  // (colaborador, data_inicio, data_fim, hora_inicio, hora_fim, motivo)
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  bool get salvo => _criado != null;

  Future<void> carregar() async {
    _erroAoCarregar = null;
    notifyListeners();

    // o negócio inteiro não escolhe profissional: nada a buscar
    if (doNegocio) {
      _carregado = true;
      notifyListeners();
      return;
    }

    final result = await _listarColaboradores(NoParams());
    if (_disposed) return;

    result.fold((failure) => _erroAoCarregar = failure, (lista) {
      _colaboradores = lista
          .where((c) => c.ativo)
          .where(
            (c) => somenteColaboradorId == null || c.id == somenteColaboradorId,
          )
          .toList();
      final inicialId = somenteColaboradorId ?? colaboradorInicialId;
      _colaborador = _colaboradores.where((c) => c.id == inicialId).firstOrNull;
      _carregado = true;
    });
    notifyListeners();
  }

  void selecionarColaborador(Colaborador? colaborador) {
    _colaborador = colaborador;
    notifyListeners();
  }

  void selecionarPeriodo(PeriodoDoBloqueio periodo) {
    _periodo = periodo;
    notifyListeners();
  }

  void selecionarDataInicio(DateTime data) {
    _dataInicio = somenteData(data);
    notifyListeners();
  }

  void alterarDiaInteiro(bool diaInteiro) {
    _diaInteiro = diaInteiro;
    notifyListeners();
  }

  void selecionarHoraInicio(Hora hora) {
    _horaInicio = hora;
    notifyListeners();
  }

  void selecionarHoraFim(Hora hora) {
    _horaFim = hora;
    notifyListeners();
  }

  // a tela já conferiu o profissional (quando há) e a faixa de horário
  Future<void> salvar({String motivo = ''}) async {
    final colaborador = _colaborador;
    if ((!doNegocio && colaborador == null) || !horarioValido) return;

    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    final result = await _criar(
      NovoBloqueioParams(
        colaboradorId: doNegocio ? null : colaborador?.id,
        dataInicio: _dataInicio,
        dataFim: dataFim,
        horaInicio: _diaInteiro ? null : _horaInicio,
        horaFim: _diaInteiro ? null : _horaFim,
        motivo: motivo,
      ),
    );
    if (_disposed) return;

    result.fold((failure) {
      if (failure is ValidationFailure && failure.fields.isNotEmpty) {
        _fieldErrors = {
          for (final e in failure.fields.entries)
            if (e.value.isNotEmpty) e.key: e.value.first,
        };
      } else {
        // bloqueio_com_cliente chega aqui: a mensagem da API já diz o que
        // fazer (reagendar ou cancelar o atendimento antes)
        _errorMessage = failure.message;
      }
    }, (criado) => _criado = criado);

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// com o que o formulário abre: o dia e o profissional abertos na agenda, ou
// o dia aberto no quadro, para fechar o horário do negócio inteiro
class BloqueioFormArgs extends Equatable {
  const BloqueioFormArgs({
    this.data,
    this.colaboradorId,
    this.doNegocio = false,
  });

  final DateTime? data;
  final int? colaboradorId;
  final bool doNegocio;

  @override
  List<Object?> get props => [data, colaboradorId, doNegocio];
}
