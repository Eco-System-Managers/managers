import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/empresa/domain/entities/empresa_config.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_config_use_case.dart';
import 'package:managers/features/empresa/presentation/providers/negocio_atual_provider.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/buscar_meu_perfil_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockBuscarConfig extends Mock implements BuscarConfigUseCase {}

class _MockBuscarMeuPerfil extends Mock implements BuscarMeuPerfilUseCase {}

const _dono = Colaborador(
  id: 1,
  nome: 'Wilson',
  email: 'dono@demo.com',
  papel: Papel.proprietario,
);

const _parceiro = Colaborador(
  id: 2,
  nome: 'Léo',
  email: 'leo@demo.com',
  papel: Papel.colaborador,
  tipo: VinculoColaborador.parceiro,
);

const _colaborador = Colaborador(
  id: 3,
  nome: 'João',
  email: 'joao@demo.com',
  papel: Papel.colaborador,
  tipo: VinculoColaborador.colaborador,
  podeCobrar: true,
);

const _config = EmpresaConfig(
  nome: 'Barbearia Demo',
  tipoAgenda: TipoAgenda.kanban,
  logoUrl: 'https://s3/logo.webp',
  onboardingConcluido: true,
);

const _barbearia = EmpresaConfig(
  nome: 'Barbearia Demo',
  tipoAgenda: TipoAgenda.horario,
  onboardingConcluido: true,
);

void main() {
  late _MockBuscarConfig buscarConfig;
  late _MockBuscarMeuPerfil buscarMeuPerfil;
  late NegocioAtualProvider negocio;

  setUpAll(() => registerFallbackValue(NoParams()));

  setUp(() {
    buscarConfig = _MockBuscarConfig();
    buscarMeuPerfil = _MockBuscarMeuPerfil();
    negocio = NegocioAtualProvider(
      buscarConfig: buscarConfig,
      buscarMeuPerfil: buscarMeuPerfil,
    );
    when(() => buscarConfig(any()))
        .thenAnswer((_) async => const Right(_config));
    when(() => buscarMeuPerfil(any()))
        .thenAnswer((_) async => const Right(_dono));
  });

  test('carrega config e perfil de uma vez', () async {
    await negocio.carregar();

    expect(negocio.carregado, isTrue);
    expect(negocio.nome, 'Barbearia Demo');
    expect(negocio.logoUrl, 'https://s3/logo.webp');
    expect(negocio.isKanban, isTrue);
    expect(negocio.ehProprietario, isTrue);
    expect(negocio.erro, isNull);
  });

  test('não recarrega se já carregou, a não ser que forcem', () async {
    await negocio.carregar();
    await negocio.carregar();
    verify(() => buscarConfig(any())).called(1);

    await negocio.carregar(forcar: true);
    verify(() => buscarConfig(any())).called(1);
  });

  test('sem perfil (404) segue como colaborador, sem erro', () async {
    when(() => buscarMeuPerfil(any())).thenAnswer(
      (_) async => const Left(NotFoundFailure(code: 'sem_colaborador')),
    );

    await negocio.carregar();

    expect(negocio.carregado, isTrue);
    expect(negocio.ehProprietario, isFalse);
    expect(negocio.erro, isNull);
  });

  test('falha na config vira erro da tela', () async {
    when(() => buscarConfig(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));

    await negocio.carregar();

    expect(negocio.carregado, isFalse);
    expect(negocio.erro, isA<NetworkFailure>());
  });

  test('atualizarConfig troca a config e avisa', () async {
    await negocio.carregar();
    var avisos = 0;
    negocio.addListener(() => avisos++);

    negocio.atualizarConfig(_config.copyWith(nome: 'Outro'));

    expect(negocio.nome, 'Outro');
    expect(avisos, 1);
  });

  test('limpar zera tudo para a próxima sessão', () async {
    await negocio.carregar();

    negocio.limpar();

    expect(negocio.carregado, isFalse);
    expect(negocio.ehProprietario, isFalse);
    expect(negocio.tipoAgenda, TipoAgenda.horario);
  });

  // a esteira é de operação compartilhada: o parceiro toca o negócio com o
  // dono e o colaborador comum só move os cards. na agenda nada muda
  group('quem pode o quê', () {
    Future<NegocioAtualProvider> entrar(
      Colaborador perfil, {
      EmpresaConfig config = _config,
    }) async {
      when(() => buscarConfig(any())).thenAnswer((_) async => Right(config));
      when(() => buscarMeuPerfil(any())).thenAnswer((_) async => Right(perfil));
      await negocio.carregar();
      return negocio;
    }

    test('o dono opera tudo, nos dois modos', () async {
      final n = await entrar(_dono);
      expect(n.papelExibido, 'Proprietário');
      expect(n.operaComODono, isTrue);
      expect(n.soMoveOsCards, isFalse);
      expect(n.veValores, isTrue);
      expect(n.podeCobrar, isTrue);
      expect(n.podeEditarServicos, isTrue);
      expect(n.veEstrutura, isTrue);
    });

    test('o parceiro da esteira opera com o dono, menos a estrutura', () async {
      final n = await entrar(_parceiro);
      expect(n.papelExibido, 'Parceiro');
      expect(n.ehParceiro, isTrue);
      expect(n.operaComODono, isTrue);
      expect(n.soMoveOsCards, isFalse);
      expect(n.veValores, isTrue);
      expect(n.podeCobrar, isTrue);
      expect(n.podeEditarServicos, isTrue);
      expect(n.podeEditarModelos, isTrue);
      expect(n.podeAjustarDia, isTrue);
      expect(n.podeFecharHorario, isTrue);
      expect(n.veEstrutura, isFalse);
      expect(n.ehProprietario, isFalse);
    });

    test('o colaborador comum da esteira só move os cards', () async {
      final n = await entrar(_colaborador);
      expect(n.papelExibido, 'Colaborador');
      expect(n.soMoveOsCards, isTrue);
      expect(n.operaComODono, isFalse);
      expect(n.veValores, isFalse);
      // a flag de cobrar não pesa na esteira
      expect(n.podeCobrar, isFalse);
      expect(n.podeReceber, isFalse);
      expect(n.podeAjustarDia, isFalse);
      expect(n.podeFecharHorario, isFalse);
      expect(n.podeEditarServicos, isFalse);
      expect(n.podeEditarModelos, isFalse);
      expect(n.veInicio, isFalse);
      expect(n.veClientes, isFalse);
      expect(n.veServicos, isFalse);
      expect(n.veContratos, isFalse);
      expect(n.veEstrutura, isFalse);
    });

    test('sem perfil na esteira, o menor acesso: só move os cards', () async {
      when(() => buscarMeuPerfil(any())).thenAnswer(
        (_) async => const Left(NotFoundFailure(code: 'sem_colaborador')),
      );
      await negocio.carregar();
      expect(negocio.soMoveOsCards, isTrue);
    });

    test('na agenda o parceiro não opera com o dono e a estrutura abre '
        'para ler', () async {
      final n = await entrar(_parceiro, config: _barbearia);
      expect(n.operaComODono, isFalse);
      expect(n.soMoveOsCards, isFalse);
      expect(n.veValores, isTrue);
      expect(n.podeCobrar, isTrue);
      expect(n.podeEditarServicos, isFalse);
      expect(n.podeFecharHorario, isFalse);
      expect(n.veEstrutura, isTrue);
      expect(n.podeBloquear, isTrue);
    });

    test('na agenda o colaborador comum segue a flag de cobrar e vê as '
        'abas', () async {
      final n = await entrar(_colaborador, config: _barbearia);
      expect(n.soMoveOsCards, isFalse);
      expect(n.veValores, isFalse);
      expect(n.podeCobrar, isTrue);
      expect(n.veInicio, isTrue);
      expect(n.veClientes, isTrue);
      expect(n.veEstrutura, isTrue);
    });
  });
}
