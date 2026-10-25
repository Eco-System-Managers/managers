import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/financeiro/domain/entities/saldo_cliente.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';
import 'package:managers/features/financeiro/domain/usecases/financeiro_use_cases.dart';

import '../../domain/entities/atendimento_kanban.dart';
import '../../domain/entities/etapa.dart';
import '../../domain/params/kanban_params.dart';
import '../../domain/usecases/kanban_use_cases.dart';

// estado de um card aberto (montado em kanban_provider.dart, na raiz da
// feature): a ficha e as ações sobre ele. toda ação devolve o atendimento
// como a API o deixou
class AtendimentoKanbanProvider extends ChangeNotifier {
  AtendimentoKanbanProvider({
    required this.id,
    required this._obter,
    required this._listarEtapas,
    required this._mover,
    required this._cobrar,
    required this._desfazerCobranca,
    required this._alterarFalta,
    required this._remover,
    required this._obterSaldo,
  });

  final int id;
  final ObterAtendimentoKanbanUseCase _obter;
  final ListarEtapasUseCase _listarEtapas;
  final MoverAtendimentoUseCase _mover;
  final CobrarAtendimentoKanbanUseCase _cobrar;
  final DesfazerCobrancaUseCase _desfazerCobranca;
  final AlterarFaltaUseCase _alterarFalta;
  final RemoverAtendimentoKanbanUseCase _remover;
  final ObterSaldoClienteUseCase _obterSaldo;

  AtendimentoKanban? _atendimento;
  List<Etapa> _etapas = const [];
  SaldoCliente? _saldo;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  bool _removido = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  AtendimentoKanban? get atendimento => _atendimento;

  // as colunas, para "mover para"
  List<Etapa> get etapas => _etapas;

  // o crédito do cliente na comanda; null quando a consulta falhou
  SaldoCliente? get saldo => _saldo;

  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro de uma ação; a ficha continua
  String? get errorMessage => _errorMessage;

  // true depois de excluir: a tela fecha
  bool get removido => _removido;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final (atendimento, etapas) = await (
      _obter(id),
      _listarEtapas(NoParams()),
    ).wait;
    if (_disposed) return;

    etapas.fold((_) {}, (lista) => _etapas = lista);
    await atendimento.fold((failure) async => _erroAoCarregar = failure, (
      a,
    ) async {
      _atendimento = a;
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

  Future<void> mover(int etapaId) =>
      _executar(() => _mover(MoverAtendimentoParams(id: id, etapaId: etapaId)));

  Future<void> alterarFalta(bool faltou) => _executar(
    () => _alterarFalta(AlterarFaltaParams(id: id, faltou: faltou)),
  );

  // devolve true quando cobrou: a folha de cobrança fecha
  Future<bool> cobrar(CobrancaParams params) async {
    await _executar(() => _cobrar(params));
    if (_errorMessage != null) return false;
    await _atualizarSaldo();
    return true;
  }

  Future<void> desfazerCobranca() async {
    await _executar(() => _desfazerCobranca(id));
    if (_errorMessage == null) await _atualizarSaldo();
  }

  // o troco e o crédito aplicado mudam a comanda
  Future<void> _atualizarSaldo() async {
    final clienteId = _atendimento?.clienteId;
    if (clienteId == null) return;
    await _carregarSaldo(clienteId);
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> remover() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _remover(id);
    if (_disposed) return;

    result.fold(
      (failure) => _errorMessage = failure.message,
      (_) => _removido = true,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _executar(
    Future<Either<Failure, AtendimentoKanban>> Function() acao,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await acao();
    if (_disposed) return;

    result.fold(
      (failure) => _errorMessage = failure.message,
      (a) => _atendimento = a,
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
