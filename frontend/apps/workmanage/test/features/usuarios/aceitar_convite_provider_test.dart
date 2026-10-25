import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao_controller.dart';
import 'package:managers/features/usuarios/domain/entities/convite.dart';
import 'package:managers/features/usuarios/domain/params/equipe_params.dart';
import 'package:managers/features/usuarios/domain/usecases/equipe_use_cases.dart';
import 'package:managers/features/usuarios/presentation/providers/aceitar_convite_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_sessao_repository.dart';

class _MockObterConvite extends Mock implements ObterConviteUseCase {}

class _MockAceitar extends Mock implements AceitarConviteUseCase {}

final _info = ConviteInfo(
  nome: 'Caio',
  email: 'caio@demo.com',
  expiraEm: DateTime(2026, 10, 27, 10),
);

void main() {
  late _MockObterConvite obterConvite;
  late _MockAceitar aceitar;
  late SessaoController sessao;

  setUpAll(() {
    registerFallbackValue(const AceitarConviteParams(token: '', senha: ''));
  });

  AceitarConviteProvider montar() => AceitarConviteProvider(
    token: 'abc-123',
    obterConvite: obterConvite,
    aceitar: aceitar,
    sessao: sessao,
  );

  setUp(() {
    obterConvite = _MockObterConvite();
    aceitar = _MockAceitar();
    sessao = SessaoController(FakeSessaoRepository());
    when(() => obterConvite('abc-123')).thenAnswer((_) async => Right(_info));
  });

  test('carregar traz para quem é o convite', () async {
    final provider = montar();

    await provider.carregar();

    expect(provider.info, _info);
    expect(provider.erroAoCarregar, isNull);
  });

  test('convite expirado ou usado vira erroAoCarregar com o detail', () async {
    when(() => obterConvite('abc-123')).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'Este convite expirou.',
          code: 'convite_expirado',
        ),
      ),
    );
    final provider = montar();

    await provider.carregar();

    expect(provider.info, isNull);
    expect(provider.erroAoCarregar?.message, 'Este convite expirou.');
  });

  test('aceitar entra na sessão que a API devolveu', () async {
    when(() => aceitar(any()))
        .thenAnswer((_) async => const Right(sessaoDeTeste));
    final provider = montar();
    await provider.carregar();

    await provider.aceitar('SenhaForte123!');

    final params =
        verify(() => aceitar(captureAny())).captured.single
            as AceitarConviteParams;
    expect(params.token, 'abc-123');
    expect(params.senha, 'SenhaForte123!');
    expect(provider.aceito, isTrue);
    expect(sessao.autenticado, isTrue);
    expect(sessao.atual, sessaoDeTeste);
  });

  test('senha fraca fica no campo; outro erro vira mensagem', () async {
    when(() => aceitar(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(message: 'Senha muito curta.', code: 'senha_fraca'),
      ),
    );
    final provider = montar();

    await provider.aceitar('123');

    expect(provider.aceito, isFalse);
    expect(provider.erroDoCampo('senha'), 'Senha muito curta.');
    expect(provider.errorMessage, isNull);
    expect(sessao.autenticado, isFalse);

    when(() => aceitar(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'Convite já foi aceito.',
          code: 'convite_ja_aceito',
        ),
      ),
    );
    await provider.aceitar('SenhaForte123!');

    expect(provider.errorMessage, 'Convite já foi aceito.');
  });
}
