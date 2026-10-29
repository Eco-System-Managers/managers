import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/empresa/domain/entities/empresa_config.dart';
import 'package:managers/features/empresa/domain/entities/nicho.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_config_use_case.dart';
import 'package:managers/features/empresa/presentation/providers/negocio_atual_provider.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';
import 'package:managers/features/servicos/domain/params/alterar_ativo_params.dart';
import 'package:managers/features/servicos/domain/params/listar_servicos_params.dart';
import 'package:managers/features/servicos/domain/usecases/alterar_ativo_servico_use_case.dart';
import 'package:managers/features/servicos/domain/usecases/listar_servicos_use_case.dart';
import 'package:managers/features/servicos/presentation/providers/servicos_provider.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/buscar_meu_perfil_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockListar extends Mock implements ListarServicosUseCase {}

class _MockAlterarAtivo extends Mock implements AlterarAtivoServicoUseCase {}

class _MockBuscarConfig extends Mock implements BuscarConfigUseCase {}

class _MockBuscarMeuPerfil extends Mock implements BuscarMeuPerfilUseCase {}

final _corte = Servico(
  id: 1,
  nome: 'Corte',
  duracao: 30,
  preco: Decimal.parse('45.5'),
);

void main() {
  late _MockListar listar;
  late _MockAlterarAtivo alterarAtivo;
  late _MockBuscarConfig buscarConfig;
  late _MockBuscarMeuPerfil buscarMeuPerfil;
  late NegocioAtualProvider negocio;
  late ServicosProvider provider;

  setUpAll(() {
    registerFallbackValue(const ListarServicosParams());
    registerFallbackValue(const AlterarAtivoParams(id: 0, ativo: false));
    registerFallbackValue(NoParams());
  });

  setUp(() async {
    listar = _MockListar();
    alterarAtivo = _MockAlterarAtivo();
    buscarConfig = _MockBuscarConfig();
    buscarMeuPerfil = _MockBuscarMeuPerfil();
    when(() => buscarConfig(any()))
        .thenAnswer((_) async => const Right(EmpresaConfig()));
    when(() => buscarMeuPerfil(any())).thenAnswer(
      (_) async => const Right(
        Colaborador(
          id: 1,
          nome: 'Wilson',
          email: 'dono@demo.com',
          papel: Papel.proprietario,
        ),
      ),
    );
    negocio = NegocioAtualProvider(
      buscarConfig: buscarConfig,
      buscarMeuPerfil: buscarMeuPerfil,
    );
    await negocio.carregar();
    provider = ServicosProvider(
      listar: listar,
      alterarAtivo: alterarAtivo,
      negocio: negocio,
    );
    when(() => listar(any())).thenAnswer((_) async => Right([_corte]));
  });

  test('carrega só os ativos por padrão', () async {
    await provider.carregar();

    final params =
        verify(() => listar(captureAny())).captured.single
            as ListarServicosParams;
    expect(params.ativo, isTrue);
    expect(params.busca, isNull);
    expect(provider.servicos, [_corte]);
    expect(provider.ehProprietario, isTrue);
  });

  test('buscar e mostrar inativos mudam os filtros e recarregam', () async {
    await provider.buscar(' corte ');
    await provider.alternarInativos(true);

    final chamadas = verify(() => listar(captureAny())).captured;
    expect((chamadas[0] as ListarServicosParams).busca, 'corte');
    expect((chamadas[1] as ListarServicosParams).ativo, isNull);
  });

  test('inativar recarrega a lista da API em vez de mexer no estado', () async {
    when(() => alterarAtivo(any()))
        .thenAnswer((_) async => Right(_corte.copyWith(ativo: false)));
    await provider.carregar();

    await provider.alterarAtivo(_corte, false);

    final params =
        verify(() => alterarAtivo(captureAny())).captured.single
            as AlterarAtivoParams;
    expect(params.id, 1);
    expect(params.ativo, isFalse);
    verify(() => listar(any())).called(2);
    expect(provider.errorMessage, isNull);
  });

  test('erro ao inativar fica na tela, com a lista intacta', () async {
    when(() => alterarAtivo(any())).thenAnswer(
      (_) async => const Left(PermissionFailure(code: 'sem_permissao')),
    );
    await provider.carregar();

    await provider.alterarAtivo(_corte, false);

    expect(provider.errorMessage, 'Você não tem permissão para isso.');
    expect(provider.servicos, [_corte]);
    verify(() => listar(any())).called(1);
  });

  test('falha ao carregar guarda o erro', () async {
    when(() => listar(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));

    await provider.carregar();

    expect(provider.carregado, isFalse);
    expect(provider.erroAoCarregar, isA<NetworkFailure>());
  });

  group('pastas', () {
    final unha = Servico(
      id: 2,
      nome: 'Pé e mão',
      nicho: Nicho.manicure,
      duracao: 60,
      preco: Decimal.parse('40'),
    );
    final escova = Servico(
      id: 3,
      nome: 'Escova',
      nicho: Nicho.cabeleireiro,
      duracao: 45,
      preco: Decimal.parse('35'),
    );
    final massagem = Servico(
      id: 4,
      nome: 'Relaxante',
      nicho: Nicho.massagem,
      duracao: 60,
      preco: Decimal.parse('90'),
      ativo: false,
    );

    setUp(() {
      negocio.atualizarConfig(
        const EmpresaConfig(nichos: [Nicho.cabeleireiro, Nicho.manicure]),
      );
      when(() => listar(any()))
          .thenAnswer((_) async => Right([unha, escova, massagem]));
    });

    test('com um nicho só a lista fica corrida', () {
      negocio.atualizarConfig(
        const EmpresaConfig(nichos: [Nicho.cabeleireiro]),
      );

      expect(provider.emPastas, isFalse);
    });

    test(
      'uma pasta por nicho, na ordem de exibição, e os removidos no fim',
      () async {
        await provider.carregar();

        expect(provider.emPastas, isTrue);
        expect(provider.pastas.map((p) => p.nicho), [
          Nicho.cabeleireiro,
          Nicho.manicure,
          null,
        ]);
        expect(provider.pastas[0].servicos, [escova]);
        expect(provider.pastas[1].servicos, [unha]);
        expect(provider.pastas[2].servicos, [massagem]);
      },
    );

    test('pasta vazia aparece, menos na busca', () async {
      when(() => listar(any())).thenAnswer((_) async => Right([escova]));

      await provider.carregar();
      expect(provider.pastas.map((p) => p.nicho), [
        Nicho.cabeleireiro,
        Nicho.manicure,
      ]);

      await provider.buscar('escova');
      expect(provider.pastas.map((p) => p.nicho), [Nicho.cabeleireiro]);
    });

    test('recolher e abrir uma pasta', () {
      provider.alternarPasta(Nicho.manicure);
      expect(provider.recolhida(Nicho.manicure), isTrue);
      expect(provider.recolhida(Nicho.cabeleireiro), isFalse);

      provider.alternarPasta(Nicho.manicure);
      expect(provider.recolhida(Nicho.manicure), isFalse);
    });
  });
}
