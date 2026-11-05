import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/bloqueio_assinatura.dart';
import 'package:managers/core/session/sessao_controller.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/assinatura/domain/entities/assinatura.dart';
import 'package:managers/features/assinatura/domain/entities/oferta_de_plano.dart';
import 'package:managers/features/assinatura/domain/repositories/loja_repository.dart';
import 'package:managers/features/assinatura/domain/usecases/assinatura_use_cases.dart';
import 'package:managers/features/assinatura/presentation/providers/assinatura_provider.dart';
import 'package:managers/features/auth/domain/usecases/logout_use_case.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_sessao_repository.dart';

class _MockObter extends Mock implements ObterAssinaturaUseCase {}

class _MockLogout extends Mock implements LogoutUseCase {}

class _MockListarPagamentos extends Mock
    implements ListarPagamentosAssinaturaUseCase {}

class _MockListarOfertas extends Mock implements ListarOfertasUseCase {}

class _MockComprar extends Mock implements ComprarPlanoUseCase {}

class _MockRestaurar extends Mock implements RestaurarComprasUseCase {}

class _MockLinkDeGerenciar extends Mock implements LinkDeGerenciarUseCase {}

Assinatura _assinatura({
  StatusAssinatura status = StatusAssinatura.trial,
  bool bloqueada = false,
  bool checkoutAberto = false,
  bool vitalicia = false,
  int equipeAtiva = 0,
}) => Assinatura(
  status: status,
  planoNome: 'Business',
  inicio: DateTime(2026, 10, 1),
  proximoVencimento: DateTime(2026, 11, 1),
  trialFim: DateTime(2026, 10, 15),
  bloqueada: bloqueada,
  checkoutAberto: checkoutAberto,
  plano: TipoPlano.business,
  vitalicia: vitalicia,
  limiteEquipe: 5,
  equipeAtiva: equipeAtiva,
);

final _pagamento = PagamentoAssinatura(
  valor: Decimal.parse('49.90'),
  status: StatusPagamentoAssinatura.pago,
  data: DateTime(2026, 10, 1),
);

OfertaDePlano _oferta(TipoPlano plano, PeriodoDoPlano periodo, String preco) =>
    OfertaDePlano(
      id: '${plano.name}/${periodo.name}',
      plano: plano,
      periodo: periodo,
      preco: Decimal.parse(preco),
      precoTexto: 'R\$ $preco',
    );

final _ofertas = [
  _oferta(TipoPlano.pro, PeriodoDoPlano.mensal, '39.90'),
  _oferta(TipoPlano.business, PeriodoDoPlano.anual, '699.90'),
  _oferta(TipoPlano.business, PeriodoDoPlano.mensal, '69.90'),
  _oferta(TipoPlano.business, PeriodoDoPlano.semestral, '389.90'),
  _oferta(TipoPlano.enterprise, PeriodoDoPlano.anual, '1199.90'),
];

void main() {
  late _MockLogout logout;
  late SessaoController sessao;
  late _MockObter obter;
  late _MockListarPagamentos listarPagamentos;
  late _MockListarOfertas listarOfertas;
  late _MockComprar comprar;
  late _MockRestaurar restaurar;
  late _MockLinkDeGerenciar linkDeGerenciar;
  late BloqueioAssinatura bloqueio;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(
      ComprarPlanoParams(oferta: _ofertas.first, negocio: ''),
    );
  });

  AssinaturaProvider montar({bool compraNoApp = true}) => AssinaturaProvider(
    obter: obter,
    listarPagamentos: listarPagamentos,
    listarOfertas: listarOfertas,
    comprar: comprar,
    restaurar: restaurar,
    linkDeGerenciar: linkDeGerenciar,
    bloqueio: bloqueio,
    logout: logout,
    sessao: sessao,
    compraNoApp: compraNoApp,
  );

  void vendaAberta({int equipeAtiva = 0, bool vitalicia = false}) {
    when(() => obter(any())).thenAnswer(
      (_) async => Right(
        _assinatura(
          checkoutAberto: true,
          equipeAtiva: equipeAtiva,
          vitalicia: vitalicia,
        ),
      ),
    );
  }

  setUp(() async {
    obter = _MockObter();
    listarPagamentos = _MockListarPagamentos();
    listarOfertas = _MockListarOfertas();
    comprar = _MockComprar();
    restaurar = _MockRestaurar();
    linkDeGerenciar = _MockLinkDeGerenciar();
    bloqueio = BloqueioAssinatura();
    logout = _MockLogout();
    sessao = SessaoController(FakeSessaoRepository());
    await sessao.entrar(sessaoDeTeste);
    when(() => logout(any())).thenAnswer((_) async => const Right(null));
    when(() => obter(any())).thenAnswer((_) async => Right(_assinatura()));
    when(
      () => listarPagamentos(any()),
    ).thenAnswer((_) async => Right([_pagamento]));
    when(() => listarOfertas(any())).thenAnswer((_) async => Right(_ofertas));
  });

  test('carregar traz a assinatura e as cobranças, e solta o bloqueio '
      'quando ela vale', () async {
    bloqueio.marcar('Assinatura inativa.');
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isTrue);
    expect(provider.assinatura, _assinatura());
    expect(provider.pagamentos, [_pagamento]);
    expect(bloqueio.bloqueada, isFalse);
  });

  test('na fase de testes o app nem fala com a loja', () async {
    final provider = montar();

    await provider.carregar();

    expect(provider.semVenda, isTrue);
    expect(provider.mostraPlanos, isFalse);
    verifyNever(() => listarOfertas(any()));
  });

  test('sem a loja configurada também não há venda', () async {
    vendaAberta();
    final provider = montar(compraNoApp: false);

    await provider.carregar();

    expect(provider.semVenda, isTrue);
    verifyNever(() => listarOfertas(any()));
  });

  test('o aviso do bloqueio só fala em assinar onde dá para assinar', () async {
    when(() => obter(any())).thenAnswer(
      (_) async => Right(_assinatura(bloqueada: true, checkoutAberto: true)),
    );
    bloqueio.marcar('Assinatura inativa. Assine um plano para continuar.');

    final semLoja = montar(compraNoApp: false);
    await semLoja.carregar();
    expect(semLoja.bloqueada, isTrue);
    expect(
      semLoja.mensagemDeBloqueio,
      'O acesso deste negócio está suspenso no momento.',
    );

    final comLoja = montar();
    await comLoja.carregar();
    expect(
      comLoja.mensagemDeBloqueio,
      'Assinatura inativa. Assine um plano para continuar.',
    );
  });

  test('com venda, carrega os planos da loja pelo negócio da sessão e '
      'começa no plano atual, no anual', () async {
    vendaAberta();
    final provider = montar();

    await provider.carregar();

    verify(() => listarOfertas(sessaoDeTeste.schemaName)).called(1);
    expect(provider.mostraPlanos, isTrue);
    expect(provider.planosDisponiveis, TipoPlano.values);
    expect(provider.planoEscolhido, TipoPlano.business);
    expect(provider.ofertasDoPlano.map((o) => o.periodo), [
      PeriodoDoPlano.mensal,
      PeriodoDoPlano.semestral,
      PeriodoDoPlano.anual,
    ]);
    expect(provider.ofertaEscolhida?.preco, Decimal.parse('699.90'));
  });

  test('quem tem equipe não vê o Pro', () async {
    vendaAberta(equipeAtiva: 3);
    final provider = montar();

    await provider.carregar();

    expect(provider.planosDisponiveis, [
      TipoPlano.business,
      TipoPlano.enterprise,
    ]);
  });

  test('o desconto é sobre o mensal do mesmo plano', () async {
    vendaAberta();
    final provider = montar();
    await provider.carregar();

    final porPeriodo = {
      for (final o in provider.ofertasDoPlano) o.periodo: provider.descontoDe(o),
    };
    expect(porPeriodo, {
      PeriodoDoPlano.mensal: 0,
      PeriodoDoPlano.semestral: 7,
      PeriodoDoPlano.anual: 17,
    });
    expect(
      provider.ofertaEscolhida?.precoPorMes,
      Decimal.parse('58.33'),
    );
  });

  test('comprar leva a oferta escolhida e guarda a assinatura nova', () async {
    vendaAberta();
    bloqueio.marcar('Assinatura inativa.');
    when(() => comprar(any())).thenAnswer(
      (_) async => Right(_assinatura(status: StatusAssinatura.ativa)),
    );
    final provider = montar();
    await provider.carregar();
    provider.escolherPeriodo(PeriodoDoPlano.mensal);

    await provider.comprar();

    final params =
        verify(() => comprar(captureAny())).captured.single
            as ComprarPlanoParams;
    expect(params.oferta.id, 'business/mensal');
    expect(params.negocio, sessaoDeTeste.schemaName);
    expect(provider.assinatura?.status, StatusAssinatura.ativa);
    expect(provider.aviso, 'Plano Business assinado.');
    expect(bloqueio.bloqueada, isFalse);
  });

  test('desistir na janela da loja não é erro; falha vira mensagem', () async {
    vendaAberta();
    final provider = montar();
    await provider.carregar();

    when(() => comprar(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(message: '', code: LojaRepository.compraCancelada),
      ),
    );
    await provider.comprar();
    expect(provider.errorMessage, isNull);
    expect(provider.aviso, isNull);

    when(() => comprar(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(message: 'A loja não concluiu.', code: 'loja_erro'),
      ),
    );
    await provider.comprar();
    expect(provider.errorMessage, 'A loja não concluiu.');
  });

  test('restaurar lê de novo e avisa', () async {
    vendaAberta();
    when(() => restaurar(any())).thenAnswer(
      (_) async => Right(_assinatura(status: StatusAssinatura.ativa)),
    );
    final provider = montar();
    await provider.carregar();

    await provider.restaurar();

    verify(() => restaurar(sessaoDeTeste.schemaName)).called(1);
    expect(provider.assinaturaAtiva, isTrue);
    expect(provider.aviso, 'Compras restauradas.');
  });

  test('vitalício não consulta a loja nem vê planos', () async {
    vendaAberta(vitalicia: true);
    final provider = montar();

    await provider.carregar();

    expect(provider.mostraPlanos, isFalse);
    expect(provider.lojaSemPlanos, isFalse);
    verifyNever(() => listarOfertas(any()));
  });

  test('a loja sem responder deixa a tela avisar', () async {
    vendaAberta();
    when(
      () => listarOfertas(any()),
    ).thenAnswer((_) async => const Left(NetworkFailure()));
    final provider = montar();

    await provider.carregar();

    expect(provider.mostraPlanos, isFalse);
    expect(provider.lojaSemPlanos, isTrue);
  });

  test('sair revoga o refresh e limpa a sessão', () async {
    final provider = montar();

    await provider.sair();

    verify(() => logout(sessaoDeTeste.refresh)).called(1);
    expect(sessao.atual, isNull);
  });

  test('404: negócio sem assinatura não é erro', () async {
    when(
      () => obter(any()),
    ).thenAnswer((_) async => const Left(NotFoundFailure()));
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isTrue);
    expect(provider.semAssinatura, isTrue);
    expect(provider.assinatura, isNull);
    expect(provider.erroAoCarregar, isNull);
  });

  test('outro erro ao carregar vira erroAoCarregar', () async {
    when(
      () => obter(any()),
    ).thenAnswer((_) async => const Left(NetworkFailure()));
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isFalse);
    expect(provider.erroAoCarregar, isA<NetworkFailure>());
  });
}
