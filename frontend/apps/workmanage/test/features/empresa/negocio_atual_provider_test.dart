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

const _config = EmpresaConfig(
  nome: 'Barbearia Demo',
  tipoAgenda: TipoAgenda.kanban,
  logoUrl: 'https://s3/logo.webp',
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
}
