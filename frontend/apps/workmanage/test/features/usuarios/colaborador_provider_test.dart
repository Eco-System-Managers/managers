import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/entities/convite.dart';
import 'package:managers/features/usuarios/domain/params/equipe_params.dart';
import 'package:managers/features/usuarios/domain/usecases/equipe_use_cases.dart';
import 'package:managers/features/usuarios/presentation/providers/colaborador_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockObter extends Mock implements ObterColaboradorUseCase {}

class _MockAtualizar extends Mock implements AtualizarColaboradorUseCase {}

class _MockConvidar extends Mock implements ConvidarColaboradorUseCase {}

class _MockListarConvites extends Mock implements ListarConvitesUseCase {}

class _MockCancelarConvite extends Mock implements CancelarConviteUseCase {}

class _MockAlterarAtivo extends Mock
    implements AlterarAtivoColaboradorUseCase {}

class _MockContarPendentes extends Mock
    implements ContarAgendamentosPendentesUseCase {}

class _MockRemover extends Mock implements RemoverColaboradorUseCase {}

const _bia = Colaborador(id: 2, nome: 'Bia', email: 'bia@demo.com');

void main() {
  late _MockObter obter;
  late _MockAtualizar atualizar;
  late _MockConvidar convidar;
  late _MockListarConvites listarConvites;
  late _MockCancelarConvite cancelarConvite;
  late _MockAlterarAtivo alterarAtivo;
  late _MockContarPendentes contarPendentes;
  late _MockRemover remover;

  setUpAll(() {
    registerFallbackValue(
      const AtualizarColaboradorParams(
        id: 0,
        dados: DadosColaborador(nome: ''),
      ),
    );
    registerFallbackValue(const ConvidarColaboradorParams(id: 0, email: ''));
    registerFallbackValue(NoParams());
    registerFallbackValue(
      const AlterarAtivoColaboradorParams(id: 0, ativo: true),
    );
  });

  ColaboradorProvider montar() => ColaboradorProvider(
    id: 2,
    obter: obter,
    atualizar: atualizar,
    convidar: convidar,
    listarConvites: listarConvites,
    cancelarConvite: cancelarConvite,
    alterarAtivo: alterarAtivo,
    contarPendentes: contarPendentes,
    remover: remover,
  );

  setUp(() {
    obter = _MockObter();
    atualizar = _MockAtualizar();
    convidar = _MockConvidar();
    listarConvites = _MockListarConvites();
    cancelarConvite = _MockCancelarConvite();
    alterarAtivo = _MockAlterarAtivo();
    contarPendentes = _MockContarPendentes();
    remover = _MockRemover();
    when(() => obter(2)).thenAnswer((_) async => const Right(_bia));
    when(() => listarConvites(any())).thenAnswer((_) async => const Right([]));
  });

  test('carregar traz a ficha', () async {
    final provider = montar();

    await provider.carregar();

    expect(provider.colaborador, _bia);
    expect(provider.erroAoCarregar, isNull);
  });

  test('carregar acha o convite pendente desta pessoa; a lista falhando '
      '(quem não é dono) não derruba a ficha', () async {
    final meu = Convite(
      id: 5,
      nome: 'Bia',
      email: 'bia@demo.com',
      aceito: false,
      criadoEm: DateTime(2026, 10, 25),
      expiraEm: DateTime(2026, 10, 27),
      colaboradorId: 2,
      link: 'http://localhost:5173/convite/abc',
    );
    final outro = Convite(
      id: 6,
      nome: 'Caio',
      email: 'caio@demo.com',
      aceito: false,
      criadoEm: DateTime(2026, 10, 25),
      expiraEm: DateTime(2026, 10, 27),
      colaboradorId: 3,
    );
    when(() => listarConvites(any()))
        .thenAnswer((_) async => Right([outro, meu]));
    final provider = montar();

    await provider.carregar();

    expect(provider.convite, meu);

    when(() => listarConvites(any()))
        .thenAnswer((_) async => const Left(PermissionFailure()));
    final semLista = montar();
    await semLista.carregar();
    expect(semLista.colaborador, _bia);
    expect(semLista.convite, isNull);
  });

  test('reenviar cancela o pendente e convida de novo para o mesmo e-mail; '
      'cancelar some com o convite', () async {
    final pendente = Convite(
      id: 5,
      nome: 'Bia',
      email: 'bia@demo.com',
      aceito: false,
      criadoEm: DateTime(2026, 10, 25),
      expiraEm: DateTime(2026, 10, 27),
      colaboradorId: 2,
    );
    final novo = Convite(
      id: 7,
      nome: 'Bia',
      email: 'bia@demo.com',
      aceito: false,
      criadoEm: DateTime(2026, 10, 26),
      expiraEm: DateTime(2026, 10, 28),
      colaboradorId: 2,
    );
    when(() => listarConvites(any()))
        .thenAnswer((_) async => Right([pendente]));
    when(() => cancelarConvite(5)).thenAnswer((_) async => const Right(null));
    when(() => convidar(any())).thenAnswer((_) async => Right(novo));
    final provider = montar();
    await provider.carregar();

    await provider.reenviarConvite();

    verify(() => cancelarConvite(5)).called(1);
    final params =
        verify(() => convidar(captureAny())).captured.single
            as ConvidarColaboradorParams;
    expect(params.email, 'bia@demo.com');
    expect(provider.convite, novo);
    expect(provider.convidado, isTrue);

    when(() => cancelarConvite(7)).thenAnswer((_) async => const Right(null));
    await provider.cancelarConvite();
    expect(provider.convite, isNull);
  });

  test(
    'salvar manda os dados e avisa; erro de validação vai para o campo',
    () async {
      when(() => atualizar(any())).thenAnswer(
        (_) async => Right(
          Colaborador(
            id: 2,
            nome: 'Bia',
            email: 'bia@demo.com',
            funcao: 'Barbeira',
            comissaoPercentual: Decimal.fromInt(40),
          ),
        ),
      );
      final provider = montar();
      await provider.carregar();

      await provider.salvar(
        DadosColaborador(
          nome: 'Bia',
          funcao: 'Barbeira',
          comissaoPercentual: Decimal.fromInt(40),
        ),
      );

      final params =
          verify(() => atualizar(captureAny())).captured.single
              as AtualizarColaboradorParams;
      expect(params.id, 2);
      expect(params.dados.funcao, 'Barbeira');
      expect(params.dados.comissaoPercentual, Decimal.fromInt(40));
      expect(provider.colaborador?.funcao, 'Barbeira');
      expect(provider.salvo, isTrue);

      when(() => atualizar(any())).thenAnswer(
        (_) async => const Left(
          ValidationFailure(
            fields: {
              'comissao_percentual': ['A comissão vai de 0 a 100.'],
            },
          ),
        ),
      );
      await provider.salvar(const DadosColaborador(nome: 'Bia'));

      expect(
        provider.erroDoCampo('comissao_percentual'),
        'A comissão vai de 0 a 100.',
      );
      expect(provider.salvo, isFalse);
    },
  );

  test(
    'convidar manda o e-mail e avisa; quem já tem acesso vira mensagem',
    () async {
      when(() => convidar(any())).thenAnswer(
        (_) async => Right(
          Convite(
            id: 5,
            nome: 'Bia',
            email: 'bia@demo.com',
            aceito: false,
            criadoEm: DateTime(2026, 10, 25),
            expiraEm: DateTime(2026, 10, 27),
          ),
        ),
      );
      final provider = montar();
      await provider.carregar();

      await provider.convidar(' bia@demo.com ');

      final params =
          verify(() => convidar(captureAny())).captured.single
              as ConvidarColaboradorParams;
      expect((params.id, params.email), (2, 'bia@demo.com'));
      expect(provider.convidado, isTrue);

      when(() => convidar(any())).thenAnswer(
        (_) async => const Left(
          ServerFailure(
            message: 'Esta pessoa já tem acesso ao app.',
            code: 'colaborador_com_acesso',
          ),
        ),
      );
      await provider.convidar('x@y.com');
      expect(provider.convidado, isFalse);
      expect(provider.errorMessage, contains('já tem acesso'));
    },
  );

  test('alterarAtivo recarrega a ficha; a API protegendo o dono vira '
      'mensagem', () async {
    when(() => alterarAtivo(any())).thenAnswer((_) async => const Right(null));
    final provider = montar();
    await provider.carregar();

    await provider.alterarAtivo(false);

    final params =
        verify(() => alterarAtivo(captureAny())).captured.single
            as AlterarAtivoColaboradorParams;
    expect(params.ativo, isFalse);
    verify(() => obter(2)).called(2);

    when(() => alterarAtivo(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'O proprietário não pode ser desativado nem removido.',
          code: 'proprietario_protegido',
        ),
      ),
    );
    await provider.alterarAtivo(false);

    expect(provider.errorMessage, contains('proprietário'));
    expect(provider.isLoading, isFalse);
  });

  test('contarPendentes devolve o total; erro vira null e mensagem', () async {
    when(() => contarPendentes(2)).thenAnswer((_) async => const Right(3));
    final provider = montar();

    expect(await provider.contarPendentes(), 3);

    when(() => contarPendentes(2))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    expect(await provider.contarPendentes(), isNull);
    expect(provider.errorMessage, isNotNull);
  });

  test('remover fecha a ficha', () async {
    when(() => remover(2)).thenAnswer((_) async => const Right(null));
    final provider = montar();
    await provider.carregar();

    await provider.remover();

    expect(provider.removido, isTrue);
  });
}
