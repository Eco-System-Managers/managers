import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/bloqueio_assinatura.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../../domain/entities/assinatura.dart';
import '../../domain/usecases/assinatura_use_cases.dart';

// estado da tela de assinatura (montado em assinatura_provider.dart, na
// raiz da feature): a assinatura, o histórico de cobranças e as ações do
// proprietário. quando a assinatura carregada não está bloqueada, o aviso
// de 402 é limpo e o router solta a tela
class AssinaturaProvider extends ChangeNotifier {
  AssinaturaProvider({
    required this._obter,
    required this._iniciar,
    required this._confirmar,
    required this._cancelar,
    required this._listarPagamentos,
    required this._bloqueio,
    this.compraNoApp = true,
  });

  final ObterAssinaturaUseCase _obter;
  final IniciarAssinaturaUseCase _iniciar;
  final ConfirmarAssinaturaUseCase _confirmar;
  final CancelarAssinaturaUseCase _cancelar;
  final ListarPagamentosAssinaturaUseCase _listarPagamentos;
  final BloqueioAssinatura _bloqueio;

  // false no iPhone: a Apple não deixa vender assinatura com pagamento de fora
  // nem apontar para ele, então lá a tela não oferece compra nenhuma (nem o
  // "Em breve"), só mostra a assinatura
  final bool compraNoApp;

  Assinatura? _assinatura;
  bool _semAssinatura = false;
  List<PagamentoAssinatura> _pagamentos = const [];
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  // null enquanto carrega ou quando o negócio não tem assinatura
  Assinatura? get assinatura => _assinatura;

  // a API respondeu 404: nunca houve assinatura (negócio antigo). a tela
  // oferece o checkout do mesmo jeito
  bool get semAssinatura => _semAssinatura;

  List<PagamentoAssinatura> get pagamentos => _pagamentos;
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro de uma ação; a tela continua
  String? get errorMessage => _errorMessage;

  // o aviso do 402 que trouxe a pessoa até aqui, se houve
  String? get mensagemDeBloqueio => _bloqueio.mensagem;

  bool get podeAssinar => _semAssinatura || (_assinatura?.podeAssinar ?? false);

  // a tela mostra a parte de comprar (os botões ou o "Em breve")
  bool get mostraCompra => compraNoApp && podeAssinar;

  // assinar pelo app ainda não está liberado: sem assinatura, também não
  bool get checkoutAberto => _assinatura?.checkoutAberto ?? false;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final (assinatura, pagamentos) = await (
      _obter(NoParams()),
      _listarPagamentos(NoParams()),
    ).wait;
    if (_disposed) return;

    assinatura.fold(
      (failure) {
        if (failure is NotFoundFailure) {
          _semAssinatura = true;
          _assinatura = null;
          _carregado = true;
        } else {
          _erroAoCarregar = failure;
        }
      },
      (a) {
        _semAssinatura = false;
        _guardar(a);
        _carregado = true;
      },
    );
    // o histórico falhando não derruba a tela
    pagamentos.fold((_) {}, (lista) => _pagamentos = lista);

    _isLoading = false;
    notifyListeners();
  }

  // devolve o link do checkout para a tela abrir no navegador; null quando
  // a API recusou (o erro fica em errorMessage)
  Future<String?> iniciar() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _iniciar(NoParams());
    if (_disposed) return null;

    final link = result.fold((failure) {
      _errorMessage = failure.message;
      return null;
    }, (l) => l);

    _isLoading = false;
    notifyListeners();
    return link;
  }

  // devolve true quando a assinatura foi vinculada
  Future<bool> confirmar(String idExterno) =>
      _executar(() => _confirmar(idExterno.trim()));

  Future<bool> cancelar() => _executar(() => _cancelar(NoParams()));

  Future<bool> _executar(
    Future<Either<Failure, Assinatura>> Function() acao,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await acao();
    if (_disposed) return false;

    final ok = result.fold(
      (failure) {
        _errorMessage = failure.message;
        return false;
      },
      (a) {
        _semAssinatura = false;
        _guardar(a);
        return true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return ok;
  }

  void _guardar(Assinatura assinatura) {
    _assinatura = assinatura;
    if (!assinatura.bloqueada) _bloqueio.limpar();
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
