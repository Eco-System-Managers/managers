import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/bloqueio_assinatura.dart';
import 'package:managers/core/session/sessao_controller.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/auth/domain/usecases/logout_use_case.dart';

import '../../domain/entities/assinatura.dart';
import '../../domain/entities/oferta_de_plano.dart';
import '../../domain/repositories/loja_repository.dart';
import '../../domain/usecases/assinatura_use_cases.dart';

// estado da tela de assinatura (montado em assinatura_provider.dart, na
// raiz da feature): a assinatura, os planos da loja, a compra e o histórico
// de cobranças. quando a assinatura carregada não está bloqueada, o aviso
// de 402 é limpo e o router solta a tela
class AssinaturaProvider extends ChangeNotifier {
  AssinaturaProvider({
    required this._obter,
    required this._listarPagamentos,
    required this._listarOfertas,
    required this._comprar,
    required this._restaurar,
    required this._linkDeGerenciar,
    required this._bloqueio,
    required this._logout,
    required this._sessao,
    this.compraNoApp = true,
  });

  final ObterAssinaturaUseCase _obter;
  final ListarPagamentosAssinaturaUseCase _listarPagamentos;
  final ListarOfertasUseCase _listarOfertas;
  final ComprarPlanoUseCase _comprar;
  final RestaurarComprasUseCase _restaurar;
  final LinkDeGerenciarUseCase _linkDeGerenciar;
  final BloqueioAssinatura _bloqueio;
  final LogoutUseCase _logout;
  final SessaoController _sessao;

  // false quando a loja deste aparelho não está configurada (sem a chave do
  // RevenueCat): aí a tela não oferece compra nenhuma
  final bool compraNoApp;

  Assinatura? _assinatura;
  bool _semAssinatura = false;
  List<PagamentoAssinatura> _pagamentos = const [];
  List<OfertaDePlano> _ofertas = const [];
  TipoPlano? _planoEscolhido;
  PeriodoDoPlano _periodoEscolhido = PeriodoDoPlano.anual;
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  String? _aviso;

  bool _saindo = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  // null enquanto carrega ou quando o negócio não tem assinatura
  Assinatura? get assinatura => _assinatura;

  // a API respondeu 404: nunca houve assinatura (negócio antigo). a tela
  // oferece os planos do mesmo jeito
  bool get semAssinatura => _semAssinatura;

  List<PagamentoAssinatura> get pagamentos => _pagamentos;
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro de uma ação; a tela continua
  String? get errorMessage => _errorMessage;

  // o que deu certo, para a tela avisar uma vez (avisoMostrado zera)
  String? get aviso => _aviso;

  // o negócio está bloqueado (402): o router prende a pessoa aqui, então a
  // tela oferece sair e excluir a conta, para ninguém ficar sem saída
  bool get bloqueada => _bloqueio.bloqueada;
  bool get saindo => _saindo;

  // assinar pelo app ainda não está liberado: sem assinatura, também não
  bool get checkoutAberto => _assinatura?.checkoutAberto ?? false;

  // onde não dá para assinar (a fase de testes, ou a loja sem configurar)
  // o app não fala de assinatura: a tela mostra só o acesso, sem plano,
  // cobranças nem "Em breve"
  bool get semVenda => !compraNoApp || !checkoutAberto;

  // o aviso do 402 que trouxe a pessoa até aqui, se houve. o texto da API
  // ("assine um plano") só aparece onde dá para assinar de verdade
  String? get mensagemDeBloqueio {
    if (!_bloqueio.bloqueada) return null;
    if (semVenda) return 'O acesso deste negócio está suspenso no momento.';
    return _bloqueio.mensagem;
  }

  bool get vitalicia => _assinatura?.vitalicia ?? false;

  // ativa, a tela fala em trocar de plano; senão, em assinar
  bool get assinaturaAtiva => _assinatura?.status == StatusAssinatura.ativa;

  // a tela mostra os planos: há venda, há o que comprar na loja e o
  // negócio não é vitalício
  bool get mostraPlanos => !semVenda && !vitalicia && _ofertas.isNotEmpty;

  // a venda está aberta, mas a loja não trouxe os planos (rede, loja fora)
  bool get lojaSemPlanos => !semVenda && !vitalicia && _ofertas.isEmpty;

  // os planos que cabem na equipe de hoje: quem tem equipe não vê o Pro
  List<TipoPlano> get planosDisponiveis {
    final equipe = _assinatura?.equipeAtiva ?? 0;
    final comOferta = _ofertas.map((o) => o.plano).toSet();
    return planosQueCabem(equipe).where(comOferta.contains).toList();
  }

  TipoPlano? get planoEscolhido => _planoEscolhido;
  PeriodoDoPlano get periodoEscolhido => _periodoEscolhido;

  // os períodos do plano escolhido, na ordem mensal, semestral, anual
  List<OfertaDePlano> get ofertasDoPlano =>
      _ofertas.where((o) => o.plano == _planoEscolhido).toList()
        ..sort((a, b) => a.periodo.index.compareTo(b.periodo.index));

  OfertaDePlano? get ofertaEscolhida => ofertasDoPlano
      .where((o) => o.periodo == _periodoEscolhido)
      .firstOrNull;

  // quanto o período economiza sobre o mensal do mesmo plano
  int descontoDe(OfertaDePlano oferta) => descontoSobreMensal(
    oferta,
    ofertasDoPlano.where((o) => o.periodo == PeriodoDoPlano.mensal).firstOrNull,
  );

  String? get _negocio => _sessao.atual?.schemaName;

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

    // a loja só é consultada quando há venda: na fase de testes o app nem
    // fala com ela
    final negocio = _negocio;
    if (_carregado && !semVenda && !vitalicia && negocio != null) {
      final ofertas = await _listarOfertas(negocio);
      if (_disposed) return;
      ofertas.fold((_) => _ofertas = const [], (lista) => _ofertas = lista);
      _escolherPlanoInicial();
    }

    _isLoading = false;
    notifyListeners();
  }

  // começa no plano que já vale (no teste, o Business) se ele couber; senão
  // no menor que comporta a equipe
  void _escolherPlanoInicial() {
    final disponiveis = planosDisponiveis;
    if (disponiveis.isEmpty) {
      _planoEscolhido = null;
      return;
    }
    final atual = _assinatura?.plano;
    _planoEscolhido = disponiveis.contains(atual) ? atual : disponiveis.first;
  }

  void escolherPlano(TipoPlano plano) {
    if (_planoEscolhido == plano) return;
    _planoEscolhido = plano;
    notifyListeners();
  }

  void escolherPeriodo(PeriodoDoPlano periodo) {
    if (_periodoEscolhido == periodo) return;
    _periodoEscolhido = periodo;
    notifyListeners();
  }

  // compra o plano e o período escolhidos; a assinatura nova já vem da API
  Future<void> comprar() async {
    final oferta = ofertaEscolhida;
    final negocio = _negocio;
    if (oferta == null || negocio == null || _isLoading) return;

    await _executar(
      () => _comprar(ComprarPlanoParams(oferta: oferta, negocio: negocio)),
      sucesso: 'Plano ${oferta.plano.nome} assinado.',
    );
  }

  Future<void> restaurar() async {
    final negocio = _negocio;
    if (negocio == null || _isLoading) return;
    await _executar(
      () => _restaurar(negocio),
      sucesso: 'Compras restauradas.',
    );
  }

  // onde a pessoa gerencia e cancela, na loja; null quando a loja não
  // informou (a tela usa o link geral da loja)
  Future<String?> linkDeGerenciar() async {
    final negocio = _negocio;
    if (negocio == null) return null;
    final result = await _linkDeGerenciar(negocio);
    return result.fold((_) => null, (link) => link);
  }

  Future<void> _executar(
    Future<Either<Failure, Assinatura>> Function() acao, {
    required String sucesso,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await acao();
    if (_disposed) return;

    result.fold(
      (failure) {
        // desistir na janela da loja não é erro
        if (failure.code != LojaRepository.compraCancelada) {
          _errorMessage = failure.message;
        }
      },
      (a) {
        _semAssinatura = false;
        _guardar(a);
        _aviso = sucesso;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  void _guardar(Assinatura assinatura) {
    _assinatura = assinatura;
    if (!assinatura.bloqueada) _bloqueio.limpar();
  }

  // revoga o refresh na API e limpa a sessão local, como em Mais; se a API
  // falhar, a sessão local é limpa do mesmo jeito e o router leva ao login
  Future<void> sair() async {
    final sessao = _sessao.atual;
    if (sessao == null || _saindo) return;

    _saindo = true;
    notifyListeners();

    await _logout(sessao.refresh);
    if (_disposed) return;

    await _sessao.sair();
  }

  void avisoMostrado() => _aviso = null;

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
