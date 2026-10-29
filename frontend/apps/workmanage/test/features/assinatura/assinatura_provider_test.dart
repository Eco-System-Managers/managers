import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/bloqueio_assinatura.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/assinatura/domain/entities/assinatura.dart';
import 'package:managers/features/assinatura/domain/usecases/assinatura_use_cases.dart';
import 'package:managers/features/assinatura/presentation/providers/assinatura_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockObter extends Mock implements ObterAssinaturaUseCase {}

class _MockIniciar extends Mock implements IniciarAssinaturaUseCase {}

class _MockConfirmar extends Mock implements ConfirmarAssinaturaUseCase {}

class _MockCancelar extends Mock implements CancelarAssinaturaUseCase {}

class _MockListarPagamentos extends Mock
    implements ListarPagamentosAssinaturaUseCase {}

Assinatura _assinatura({
  StatusAssinatura status = StatusAssinatura.trial,
  bool bloqueada = false,
  bool checkoutAberto = false,
}) => Assinatura(
  status: status,
  planoNome: 'Pro',
  inicio: DateTime(2026, 10, 1),
  proximoVencimento: DateTime(2026, 11, 1),
  trialFim: DateTime(2026, 10, 15),
  bloqueada: bloqueada,
  checkoutAberto: checkoutAberto,
);

final _pagamento = PagamentoAssinatura(
  valor: Decimal.parse('49.90'),
  status: StatusPagamentoAssinatura.pago,
  data: DateTime(2026, 10, 1),
);

void main() {
  late _MockObter obter;
  late _MockIniciar iniciar;
  late _MockConfirmar confirmar;
  late _MockCancelar cancelar;
  late _MockListarPagamentos listarPagamentos;
  late BloqueioAssinatura bloqueio;

  setUpAll(() => registerFallbackValue(NoParams()));

  AssinaturaProvider montar() => AssinaturaProvider(
    obter: obter,
    iniciar: iniciar,
    confirmar: confirmar,
    cancelar: cancelar,
    listarPagamentos: listarPagamentos,
    bloqueio: bloqueio,
  );

  setUp(() {
    obter = _MockObter();
    iniciar = _MockIniciar();
    confirmar = _MockConfirmar();
    cancelar = _MockCancelar();
    listarPagamentos = _MockListarPagamentos();
    bloqueio = BloqueioAssinatura();
    when(() => obter(any())).thenAnswer((_) async => Right(_assinatura()));
    when(() => listarPagamentos(any()))
        .thenAnswer((_) async => Right([_pagamento]));
  });

  test('carregar traz a assinatura e as cobranças, e solta o bloqueio '
      'quando ela vale', () async {
    bloqueio.marcar('Assinatura inativa.');
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isTrue);
    expect(provider.assinatura, _assinatura());
    expect(provider.pagamentos, [_pagamento]);
    expect(provider.podeAssinar, isTrue);
    expect(bloqueio.bloqueada, isFalse);
  });

  test('assinatura bloqueada mantém o aviso', () async {
    when(() => obter(any()))
        .thenAnswer((_) async => Right(_assinatura(bloqueada: true)));
    bloqueio.marcar('Assinatura inativa.');
    final provider = montar();

    await provider.carregar();

    expect(bloqueio.bloqueada, isTrue);
    expect(provider.mensagemDeBloqueio, 'Assinatura inativa.');
  });

  test('o checkout segue a API; sem assinatura fica fechado', () async {
    final provider = montar();
    await provider.carregar();
    expect(provider.checkoutAberto, isFalse);

    when(() => obter(any()))
        .thenAnswer((_) async => Right(_assinatura(checkoutAberto: true)));
    await provider.carregar();
    expect(provider.checkoutAberto, isTrue);

    when(() => obter(any()))
        .thenAnswer((_) async => const Left(NotFoundFailure()));
    await provider.carregar();
    expect(provider.checkoutAberto, isFalse);
  });

  test('404: negócio sem assinatura não é erro, e pode assinar', () async {
    when(() => obter(any()))
        .thenAnswer((_) async => const Left(NotFoundFailure()));
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isTrue);
    expect(provider.semAssinatura, isTrue);
    expect(provider.assinatura, isNull);
    expect(provider.podeAssinar, isTrue);
    expect(provider.erroAoCarregar, isNull);
  });

  test('outro erro ao carregar vira erroAoCarregar', () async {
    when(() => obter(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isFalse);
    expect(provider.erroAoCarregar, isA<NetworkFailure>());
  });

  test('iniciar devolve o link; recusa vira mensagem e null', () async {
    when(() => iniciar(any()))
        .thenAnswer((_) async => const Right('https://mp.test/checkout/1'));
    final provider = montar();

    expect(await provider.iniciar(), 'https://mp.test/checkout/1');

    when(() => iniciar(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'O plano de assinatura não está configurado.',
          code: 'plano_nao_configurado',
        ),
      ),
    );
    expect(await provider.iniciar(), isNull);
    expect(provider.errorMessage, contains('não está configurado'));
  });

  test('confirmar vincula e solta o bloqueio; cancelar atualiza', () async {
    when(() => confirmar('pre-123')).thenAnswer(
      (_) async => Right(_assinatura(status: StatusAssinatura.ativa)),
    );
    when(() => cancelar(any())).thenAnswer(
      (_) async => Right(_assinatura(status: StatusAssinatura.cancelada)),
    );
    bloqueio.marcar('Assinatura inativa.');
    final provider = montar();

    expect(await provider.confirmar(' pre-123 '), isTrue);
    expect(provider.assinatura?.status, StatusAssinatura.ativa);
    expect(provider.podeAssinar, isFalse);
    expect(bloqueio.bloqueada, isFalse);

    expect(await provider.cancelar(), isTrue);
    expect(provider.assinatura?.status, StatusAssinatura.cancelada);

    when(() => confirmar('x')).thenAnswer(
      (_) async => const Left(
        ServerFailure(message: 'Recusada.', code: 'assinatura_recusada'),
      ),
    );
    expect(await provider.confirmar('x'), isFalse);
    expect(provider.errorMessage, 'Recusada.');
  });
}
