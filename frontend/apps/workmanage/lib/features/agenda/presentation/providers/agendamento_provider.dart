import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/financeiro/domain/entities/saldo_cliente.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';
import 'package:managers/features/financeiro/domain/usecases/financeiro_use_cases.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';
import 'package:managers/features/servicos/domain/params/listar_servicos_params.dart';
import 'package:managers/features/servicos/domain/usecases/listar_servicos_use_case.dart';

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
    required this._trocarServicos,
    required this._cobrar,
    required this._listarSlots,
    required this._obterSaldo,
    this._listarServicos,
  });

  final int id;
  final ObterAgendamentoUseCase _obter;
  final AlterarStatusAgendamentoUseCase _alterarStatus;
  final RemarcarAgendamentoUseCase _remarcar;
  final TrocarServicosAgendamentoUseCase _trocarServicos;
  final CobrarAgendamentoUseCase _cobrar;
  final ListarSlotsUseCase _listarSlots;
  final ObterSaldoClienteUseCase _obterSaldo;

  // o catálogo, para mudar os serviços antes do atendimento e na cobrança.
  // opcional: sem ele só dá para tirar serviços, não incluir
  final ListarServicosUseCase? _listarServicos;

  Agendamento? _agendamento;
  SaldoCliente? _saldo;
  List<Servico> _servicos = const [];
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

  // os serviços do agendamento como itens do catálogo, com o preço
  // combinado: é o que vale para quem fica numa troca
  List<Servico> get servicosDoAgendamento {
    final agendamento = _agendamento;
    if (agendamento == null) return const [];
    return [
      for (final item in agendamento.servicos)
        (_servicos.where((s) => s.id == item.servicoId).firstOrNull ??
                Servico(
                  id: item.servicoId,
                  nome: item.nome,
                  duracao: item.duracao,
                  preco: item.precoCobrado,
                ))
            .copyWith(preco: item.precoCobrado),
    ];
  }

  // o que dá para escolher ao mudar os serviços (na ficha e na cobrança): os
  // ativos que o profissional do agendamento faz, com os que já estão nele
  // no lugar, pelo preço combinado (mesmo os que saíram do catálogo ou que
  // ele deixou de fazer depois de marcado). sem catálogo, só os atuais
  List<Servico> get servicosParaEscolher {
    final agendamento = _agendamento;
    if (agendamento == null) return const [];
    final colaboradorId = agendamento.colaboradorId;
    final atuais = {for (final s in servicosDoAgendamento) s.id: s};
    final doProfissional = _servicos.where(
      (s) =>
          colaboradorId == null ||
          s.colaboradores.isEmpty ||
          s.colaboradores.contains(colaboradorId),
    );
    final ids = {for (final s in doProfissional) s.id};
    return [
      for (final s in doProfissional) atuais[s.id] ?? s,
      for (final s in atuais.values)
        if (!ids.contains(s.id)) s,
    ];
  }

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final (result, _) = await (_obter(id), _carregarServicos()).wait;
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

  // o catálogo ativo, para mudar os serviços. falhou (ou não há use case),
  // a ficha segue só com os serviços que o agendamento já tem
  Future<void> _carregarServicos() async {
    final listar = _listarServicos;
    if (listar == null) return;
    final result = await listar(const ListarServicosParams(ativo: true));
    result.fold((_) {}, (lista) => _servicos = lista);
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

  // a lista nova inteira, antes do atendimento. o erro (horario_conflito
  // com o tempo novo, agendamento_encerrado) fica em errorMessage
  Future<void> trocarServicos(List<int> servicoIds) async {
    await _executar(
      () =>
          _trocarServicos(TrocarServicosParams(id: id, servicoIds: servicoIds)),
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

  // a grade para remarcar: os mesmos serviços (o tempo de todos) e o mesmo
  // profissional, em outro dia. sem profissional ou sem serviço não há
  // grade; a tela pede a hora livre
  Future<List<Slot>> slotsParaRemarcar(DateTime data) async {
    final agendamento = _agendamento;
    final colaboradorId = agendamento?.colaboradorId;
    if (agendamento == null ||
        agendamento.servicos.isEmpty ||
        colaboradorId == null) {
      return const [];
    }
    final result = await _listarSlots(
      SlotsParams(
        data: data,
        servicoIds: [for (final s in agendamento.servicos) s.servicoId],
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
