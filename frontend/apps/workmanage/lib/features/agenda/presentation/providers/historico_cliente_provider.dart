import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/agendamento.dart';
import '../../domain/usecases/agenda_use_cases.dart';

// estado do histórico de atendimentos de um cliente (montado em
// agenda_provider.dart, na raiz da feature), para a ficha dele
class HistoricoClienteProvider extends ChangeNotifier {
  HistoricoClienteProvider({required this.clienteId, required this._listar});

  final int clienteId;
  final ListarAgendamentosDoClienteUseCase _listar;

  List<Agendamento> _agendamentos = const [];
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erro;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  // do mais recente para o mais antigo
  List<Agendamento> get agendamentos => _agendamentos;
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erro => _erro;

  int get total => _agendamentos.length;

  // o que o cliente já pagou nos atendimentos concluídos
  Decimal get totalPago => _agendamentos
      .where((a) => a.pago)
      .fold(Decimal.fromInt(0), (soma, a) => soma + a.valorPago);

  Future<void> carregar() async {
    _isLoading = true;
    _erro = null;
    notifyListeners();

    final result = await _listar(clienteId);
    if (_disposed) return;

    result.fold((failure) => _erro = failure, (lista) {
      // a API manda em ordem crescente; a ficha quer o último primeiro
      _agendamentos = [...lista]
        ..sort((a, b) => b.dataHora.compareTo(a.dataHora));
      _carregado = true;
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
