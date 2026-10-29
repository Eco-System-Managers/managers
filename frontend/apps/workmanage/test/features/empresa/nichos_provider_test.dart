import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/empresa/domain/entities/empresa_config.dart';
import 'package:managers/features/empresa/domain/entities/nicho.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_config_use_case.dart';
import 'package:managers/features/empresa/domain/usecases/salvar_config_use_case.dart';
import 'package:managers/features/empresa/presentation/providers/negocio_atual_provider.dart';
import 'package:managers/features/empresa/presentation/providers/nichos_provider.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';
import 'package:managers/features/servicos/domain/params/listar_servicos_params.dart';
import 'package:managers/features/servicos/domain/usecases/listar_servicos_use_case.dart';
import 'package:managers/features/usuarios/domain/usecases/buscar_meu_perfil_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockSalvarConfig extends Mock implements SalvarConfigUseCase {}

class _MockListarServicos extends Mock implements ListarServicosUseCase {}

class _MockBuscarConfig extends Mock implements BuscarConfigUseCase {}

class _MockBuscarMeuPerfil extends Mock implements BuscarMeuPerfilUseCase {}

const _config = EmpresaConfig(
  nome: 'Studio',
  nichos: [Nicho.cabeleireiro, Nicho.manicure],
);

Servico _servico(int id, Nicho nicho) => Servico(
  id: id,
  nome: 'Serviço $id',
  nicho: nicho,
  duracao: 30,
  preco: Decimal.parse('50'),
);

void main() {
  late _MockSalvarConfig salvarConfig;
  late _MockListarServicos listarServicos;
  late NegocioAtualProvider negocio;
  late NichosProvider provider;

  setUpAll(() {
    registerFallbackValue(const EmpresaConfig());
    registerFallbackValue(const ListarServicosParams());
  });

  setUp(() {
    salvarConfig = _MockSalvarConfig();
    listarServicos = _MockListarServicos();
    negocio = NegocioAtualProvider(
      buscarConfig: _MockBuscarConfig(),
      buscarMeuPerfil: _MockBuscarMeuPerfil(),
    )..atualizarConfig(_config);
    provider = NichosProvider(
      negocio: negocio,
      salvarConfig: salvarConfig,
      listarServicos: listarServicos,
    );
  });

  test('abre com os nichos e a área do negócio, sem nada para salvar', () {
    expect(provider.escolhidos, [Nicho.cabeleireiro, Nicho.manicure]);
    expect(provider.area, AreaNicho.belezaBemEstar);
    expect(provider.podeSalvar, isFalse);
  });

  test('não salva sem nenhum nicho', () {
    provider.alternar(Nicho.cabeleireiro);
    provider.alternar(Nicho.manicure);

    expect(provider.escolhidos, isEmpty);
    expect(provider.podeSalvar, isFalse);
  });

  test('conta só os serviços ativos dos nichos que saíram', () async {
    when(() => listarServicos(any())).thenAnswer(
      (_) async => Right([
        _servico(1, Nicho.cabeleireiro),
        _servico(2, Nicho.manicure),
        _servico(3, Nicho.manicure),
      ]),
    );

    provider.alternar(Nicho.manicure);
    final afetados = await provider.contarServicosAfetados();

    expect(provider.removidos, [Nicho.manicure]);
    expect(afetados, 2);
    final params =
        verify(() => listarServicos(captureAny())).captured.single
            as ListarServicosParams;
    expect(params.ativo, isTrue);
  });

  test('sem nicho removido, não consulta os serviços', () async {
    provider.alternar(Nicho.massagem);

    expect(await provider.contarServicosAfetados(), 0);
    verifyNever(() => listarServicos(any()));
  });

  test('falha na contagem vira mensagem e devolve null', () async {
    when(() => listarServicos(any())).thenAnswer(
      (_) async => const Left(NetworkFailure(message: 'Sem conexão')),
    );

    provider.alternar(Nicho.manicure);

    expect(await provider.contarServicosAfetados(), isNull);
    expect(provider.errorMessage, 'Sem conexão');
  });

  test('salvar manda os nichos e atualiza o negócio', () async {
    const salva = EmpresaConfig(
      nome: 'Studio',
      nichos: [Nicho.cabeleireiro, Nicho.massagem],
    );
    when(() => salvarConfig(any())).thenAnswer((_) async => const Right(salva));

    provider.alternar(Nicho.manicure);
    provider.alternar(Nicho.massagem);
    await provider.salvar();

    final enviada =
        verify(() => salvarConfig(captureAny())).captured.single
            as EmpresaConfig;
    expect(enviada.nichos, [Nicho.cabeleireiro, Nicho.massagem]);
    expect(enviada.nome, 'Studio');
    expect(negocio.config?.nichos, salva.nichos);
    expect(provider.salvo, isTrue);
  });
}
