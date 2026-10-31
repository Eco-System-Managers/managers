import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/clientes/domain/entities/porte.dart';
import 'package:managers/features/empresa/domain/entities/empresa_config.dart';
import 'package:managers/features/empresa/domain/entities/nicho.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_config_use_case.dart';
import 'package:managers/features/empresa/presentation/providers/negocio_atual_provider.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';
import 'package:managers/features/servicos/domain/params/alterar_ativo_params.dart';
import 'package:managers/features/servicos/domain/usecases/alterar_ativo_servico_use_case.dart';
import 'package:managers/features/servicos/domain/usecases/atualizar_servico_use_case.dart';
import 'package:managers/features/servicos/domain/usecases/criar_servico_use_case.dart';
import 'package:managers/features/servicos/domain/usecases/obter_servico_use_case.dart';
import 'package:managers/features/servicos/presentation/providers/servico_form_provider.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/buscar_meu_perfil_use_case.dart';
import 'package:managers/features/usuarios/domain/usecases/listar_colaboradores_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockObter extends Mock implements ObterServicoUseCase {}

class _MockCriar extends Mock implements CriarServicoUseCase {}

class _MockAtualizar extends Mock implements AtualizarServicoUseCase {}

class _MockAlterarAtivo extends Mock implements AlterarAtivoServicoUseCase {}

class _MockListarColaboradores extends Mock
    implements ListarColaboradoresUseCase {}

class _MockBuscarConfig extends Mock implements BuscarConfigUseCase {}

class _MockBuscarMeuPerfil extends Mock implements BuscarMeuPerfilUseCase {}

final _corte = Servico(
  id: 5,
  nome: 'Corte',
  duracao: 30,
  preco: Decimal.parse('45.5'),
  colaboradores: const [1],
);

const _equipe = [
  Colaborador(id: 1, nome: 'Ana', email: 'ana@demo.com'),
  Colaborador(id: 2, nome: 'Bia', email: 'bia@demo.com'),
];

void main() {
  late _MockObter obter;
  late _MockCriar criar;
  late _MockAtualizar atualizar;
  late _MockAlterarAtivo alterarAtivo;
  late _MockListarColaboradores listarColaboradores;
  late NegocioAtualProvider negocio;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(_corte);
    registerFallbackValue(const AlterarAtivoParams(id: 0, ativo: false));
  });

  ServicoFormProvider montar(int? id) {
    return ServicoFormProvider(
      id: id,
      obter: obter,
      criar: criar,
      atualizar: atualizar,
      alterarAtivo: alterarAtivo,
      listarColaboradores: listarColaboradores,
      negocio: negocio,
    );
  }

  setUp(() {
    obter = _MockObter();
    criar = _MockCriar();
    atualizar = _MockAtualizar();
    alterarAtivo = _MockAlterarAtivo();
    listarColaboradores = _MockListarColaboradores();
    negocio = NegocioAtualProvider(
      buscarConfig: _MockBuscarConfig(),
      buscarMeuPerfil: _MockBuscarMeuPerfil(),
    )..atualizarConfig(const EmpresaConfig(nichos: [Nicho.cabeleireiro]));
    when(() => listarColaboradores(any()))
        .thenAnswer((_) async => const Right(_equipe));
    when(() => obter(5)).thenAnswer((_) async => Right(_corte));
  });

  test('novo: carrega só a equipe', () async {
    final provider = montar(null);

    await provider.carregar();

    expect(provider.ehNovo, isTrue);
    expect(provider.carregado, isTrue);
    expect(provider.servico, isNull);
    expect(provider.colaboradores, _equipe);
    verifyNever(() => obter(any()));
  });

  test('edição: carrega a equipe e o serviço', () async {
    final provider = montar(5);

    await provider.carregar();

    expect(provider.ehNovo, isFalse);
    expect(provider.servico, _corte);
    expect(provider.colaboradores.length, 2);
  });

  test('novo salva com criar e fecha', () async {
    when(() => criar(any())).thenAnswer(
      (invocation) async => Right(
        (invocation.positionalArguments.single as Servico).copyWith(id: 9),
      ),
    );
    final provider = montar(null)..carregar();

    await provider.salvar(_corte.copyWith(id: 0));

    expect(provider.salvo, isTrue);
    expect(provider.servico?.id, 9);
    verifyNever(() => atualizar(any()));
  });

  test('edição salva com atualizar, levando o id', () async {
    when(() => atualizar(any())).thenAnswer(
      (invocation) async =>
          Right(invocation.positionalArguments.single as Servico),
    );
    final provider = montar(5);
    await provider.carregar();

    await provider.salvar(_corte.copyWith(id: 0, nome: 'Corte e barba'));

    final enviado =
        verify(() => atualizar(captureAny())).captured.single as Servico;
    expect(enviado.id, 5);
    expect(enviado.nome, 'Corte e barba');
    expect(provider.salvo, isTrue);
  });

  test('erro de validação vai para o campo', () async {
    when(() => criar(any())).thenAnswer(
      (_) async => const Left(
        ValidationFailure(
          fields: {
            'taxa_cancelamento_valor': [
              'O percentual deve estar entre 0 e 30%.',
            ],
          },
        ),
      ),
    );
    final provider = montar(null);

    await provider.salvar(_corte);

    expect(provider.salvo, isFalse);
    expect(
      provider.erroDoCampo('taxa_cancelamento_valor'),
      'O percentual deve estar entre 0 e 30%.',
    );
    expect(provider.errorMessage, isNull);

    provider.limparErroDoCampo('taxa_cancelamento_valor');
    expect(provider.erroDoCampo('taxa_cancelamento_valor'), isNull);
  });

  test('inativar fecha a tela com o serviço inativo', () async {
    when(() => alterarAtivo(any()))
        .thenAnswer((_) async => Right(_corte.copyWith(ativo: false)));
    final provider = montar(5);
    await provider.carregar();

    await provider.alterarAtivo(false);

    expect(provider.salvo, isTrue);
    expect(provider.servico?.ativo, isFalse);
  });

  test(
    'falha ao carregar a equipe guarda o erro e não busca o serviço',
    () async {
      when(() => listarColaboradores(any()))
          .thenAnswer((_) async => const Left(NetworkFailure()));
      final provider = montar(5);

      await provider.carregar();

      expect(provider.carregado, isFalse);
      expect(provider.erroAoCarregar, isA<NetworkFailure>());
      verifyNever(() => obter(any()));
    },
  );

  group('nicho', () {
    test('com um nicho só não há o que escolher', () {
      final provider = montar(null);

      expect(provider.nichos, [Nicho.cabeleireiro]);
      expect(provider.escolheNicho, isFalse);
    });

    test('com dois ou mais, o serviço escolhe a pasta', () {
      negocio.atualizarConfig(
        const EmpresaConfig(nichos: [Nicho.cabeleireiro, Nicho.manicure]),
      );

      expect(montar(null).escolheNicho, isTrue);
    });
  });

  group('porte', () {
    test('no modo horário não há porte', () {
      final provider = montar(null);

      expect(provider.portes, isEmpty);
      expect(provider.escolhePorte, isFalse);
    });

    test('na esteira, os portes do que o negócio recebe', () {
      negocio.atualizarConfig(
        const EmpresaConfig(
          nichos: [Nicho.banhoTosa],
          tipoAgenda: TipoAgenda.kanban,
          tipoObjeto: TipoObjeto.pet,
        ),
      );
      final provider = montar(null);

      expect(provider.escolhePorte, isTrue);
      expect(provider.portes, Porte.doTipo(TipoObjeto.pet));
    });
  });
}
