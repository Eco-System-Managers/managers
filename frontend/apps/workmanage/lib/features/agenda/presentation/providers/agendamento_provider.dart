import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/financeiro/domain/entities/saldo_cliente.dart';
import 'package:managers/features/financeiro/domain/usecases/financeiro_use_cases.dart';

import '../../domain/entities/agendamento.dart';
import '../../domain/entities/slot.dart';
import '../../domain/params/agenda_params.dart';
import '../../domain/usecases/agenda_use_cases.dart';

// estado de um agendamento aberto (montado em agenda_provider.dart, na raiz
// da feature): a ficha e as ações sobre ele. toda ação devolve o
// agendamento como a API o deixou; a tela nunca muda o status por conta
class AgendamentoProvider extends ChangeNotifier {
  AgendamentoProvider({
    required this.id,
    required this._obter,
    required this._alterarStatus,
    required this._remarcar,
    required this._cobrar,
    required this._listarSlots,
    required this._obterSaldo,
  });

  final int id;
  final ObterAgendamentoUseCase _obter;
  final AlterarStatusAgendamentoUseCase _alterarStatus;
  final RemarcarAgendamentoUseCase _remarcar;
  final CobrarAgendamentoUseCase _cobrar;
  final ListarSlotsUseCase _listarSlots;
  final ObterSaldoClienteUseCase _obterSaldo;

  Agendamento? _agendamento;
  SaldoCliente? _saldo;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  bool _cancelado = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  Agendamento? get agendamento => _agendamento;

  // o crédito do cliente na comanda, para a cobrança oferecer; null quando
  // a consulta falhou (a cobrança segue sem crédito)
  SaldoCliente? get saldo => _saldo;

  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro de uma ação; a ficha continua na tela
  String? get errorMessage => _errorMessage;

  // true depois de cancelar: a tela fecha, o dia não lista cancelados
  bool get cancelado => _cancelado;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final result = await _obter(id);
    if (_disposed) return;

    await result.fold((failure) async => _erroAoCarregar = failure, (a) async {
      _agendamento = a;
      await _carregarSaldo(a.clienteId);
    });
    if (_disposed) return;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _carregarSaldo(int clienteId) async {
    final result = await _obterSaldo(clienteId);
    result.fold((_) => _saldo = null, (s) => _saldo = s);
  }

  Future<void> alterarStatus(StatusAgendamento status) async {
    await _executar(
      () => _alterarStatus(AlterarStatusParams(id: id, status: status)),
    );
    if (status == StatusAgendamento.cancelado && _errorMessage == null) {
      _cancelado = true;
      notifyListeners();
    }
  }

  Future<void> cancelar() => alterarStatus(StatusAgendamento.cancelado);

  Future<void> remarcar(DateTime dataHora) async {
    await _executar(
      () => _remarcar(
        RemarcarParams(
          id: id,
          dataHora: dataHora,
          colaboradorId: _agendamento?.colaboradorId,
        ),
      ),
    );
  }

  // devolve true quando cobrou: a folha de cobrança fecha. o erro (soma que
  // não fecha, sem pagamentos, crédito insuficiente) fica em errorMessage
  Future<bool> cobrar(CobrancaParams params) async {
    await _executar(() => _cobrar(params));
    if (_errorMessage != null) return false;
    // o troco e o crédito aplicado mudaram a comanda
    final clienteId = _agendamento?.clienteId;
    if (clienteId != null) {
      await _carregarSaldo(clienteId);
      if (_disposed) return true;
      notifyListeners();
    }
    return true;
  }

  // a grade para remarcar: o mesmo serviço e profissional, em outro dia.
  // sem profissional ou sem serviço não há grade; a tela pede a hora livre
  Future<List<Slot>> slotsParaRemarcar(DateTime data) async {
    final agendamento = _agendamento;
    final servicoId = agendamento?.servicos.firstOrNull?.servicoId;
    final colaboradorId = agendamento?.colaboradorId;
    if (servicoId == null || colaboradorId == null) return const [];
    final result = await _listarSlots(
      SlotsParams(
        data: data,
        servicoId: servicoId,
        colaboradorId: colaboradorId,
      ),
    );
    return result.fold((_) => const [], (slots) => slots);
  }

  Future<void> _executar(
    Future<Either<Failure, Agendamento>> Function() acao,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await acao();
    if (_disposed) return;

    result.fold(
      (failure) => _errorMessage = failure.message,
      (a) => _agendamento = a,
    );

    _isLoading = false;
    notifyListeners();
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
