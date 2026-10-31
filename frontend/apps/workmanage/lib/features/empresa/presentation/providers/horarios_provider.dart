import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../../domain/entities/horario_funcionamento.dart';
import '../../domain/usecases/buscar_horarios_use_case.dart';
import '../../domain/usecases/salvar_horarios_use_case.dart';
import 'horarios_validacao.dart';
import 'negocio_atual_provider.dart';

// estado da tela "Horários" das configurações (montado em
// empresa_provider.dart): carrega os sete dias, deixa editar e salva
class HorariosProvider extends ChangeNotifier {
  HorariosProvider({
    required this._negocio,
    required this._buscarHorarios,
    required this._salvarHorarios,
  });

  final NegocioAtualProvider _negocio;
  final BuscarHorariosUseCase _buscarHorarios;
  final SalvarHorariosUseCase _salvarHorarios;

  List<HorarioFuncionamento> _horarios = [];
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  bool _salvo = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  List<HorarioFuncionamento> get horarios => List.unmodifiable(_horarios);
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;
  String? get errorMessage => _errorMessage;
  bool get salvo => _salvo;

  // o máximo no dia e o ao mesmo tempo só existem na esteira
  bool get isKanban => _negocio.isKanban;

  // o dia que dá nome ao "Repetir segunda nos outros dias"; null com a
  // semana toda fechada
  HorarioFuncionamento? get primeiroDiaAberto => primeiroDiaAbertoDe(_horarios);

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final result = await _buscarHorarios(NoParams());
    if (_disposed) return;

    result.fold((failure) => _erroAoCarregar = failure, (horarios) {
      _horarios = horarios;
      _carregado = true;
    });

    _isLoading = false;
    notifyListeners();
  }

  // cada mudança num dia troca o horário daquele dia na lista
  void atualizarHorario(HorarioFuncionamento horario) {
    _horarios = [for (final h in _horarios) h.dia == horario.dia ? horario : h];
    _errorMessage = null;
    notifyListeners();
  }

  // copia os horários e os números do primeiro dia aberto para os outros,
  // sem abrir nem fechar dia nenhum
  void repetirPrimeiroDiaNosOutros() {
    _horarios = repetirPrimeiroDiaAberto(_horarios);
    _errorMessage = null;
    notifyListeners();
  }

  String? erroDoDia(HorarioFuncionamento horario) =>
      erroDoHorario(horario, isKanban: isKanban);

  Future<void> salvar() async {
    final erro = erroDaSemana(_horarios, isKanban: isKanban);
    if (erro != null) {
      _errorMessage = erro;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _salvarHorarios(_horarios);
    if (_disposed) return;

    result.fold(
      (failure) {
        _errorMessage = failure is ValidationFailure
            ? failure.resumo
            : failure.message;
      },
      (salvos) {
        _horarios = salvos;
        _salvo = true;
      },
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
