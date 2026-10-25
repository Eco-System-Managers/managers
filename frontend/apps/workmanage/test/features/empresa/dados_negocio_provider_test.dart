import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/empresa/domain/entities/empresa_config.dart';
import 'package:managers/features/empresa/domain/entities/endereco.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_config_use_case.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_endereco_por_cep_use_case.dart';
import 'package:managers/features/empresa/domain/usecases/salvar_config_use_case.dart';
import 'package:managers/features/empresa/presentation/providers/dados_negocio_provider.dart';
import 'package:managers/features/empresa/presentation/providers/negocio_atual_provider.dart';
import 'package:managers/features/empresa/presentation/widgets/dados_negocio_form.dart';
import 'package:managers/features/usuarios/domain/usecases/buscar_meu_perfil_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockSalvarConfig extends Mock implements SalvarConfigUseCase {}

class _MockBuscarCep extends Mock implements BuscarEnderecoPorCepUseCase {}

class _MockBuscarConfig extends Mock implements BuscarConfigUseCase {}

class _MockBuscarMeuPerfil extends Mock implements BuscarMeuPerfilUseCase {}

const _config = EmpresaConfig(
  nome: 'Barbearia Demo',
  telefone: '19999990000',
  tipoDocumento: TipoDocumento.cpf,
  documento: '52998224725',
  cep: '13604512',
  endereco: 'Rua Um',
  numero: '10',
  cidade: 'Araras',
  uf: 'SP',
  onboardingConcluido: true,
);

const _dados = DadosNegocio(
  nome: 'Barbearia Nova',
  telefone: '19988887777',
  tipoDocumento: TipoDocumento.cpf,
  documento: '52998224725',
  numero: '12',
);

void main() {
  late _MockSalvarConfig salvarConfig;
  late _MockBuscarCep buscarCep;
  late NegocioAtualProvider negocio;
  late DadosNegocioProvider provider;

  setUpAll(() => registerFallbackValue(const EmpresaConfig()));

  setUp(() {
    salvarConfig = _MockSalvarConfig();
    buscarCep = _MockBuscarCep();
    negocio = NegocioAtualProvider(
      buscarConfig: _MockBuscarConfig(),
      buscarMeuPerfil: _MockBuscarMeuPerfil(),
    )..atualizarConfig(_config);
    provider = DadosNegocioProvider(
      negocio: negocio,
      salvarConfig: salvarConfig,
      buscarEnderecoPorCep: buscarCep,
    );
  });

  test('abre com a config do negócio atual', () {
    expect(provider.config, _config);
  });

  test(
    'salvar manda a config com os dados do formulário e atualiza o app',
    () async {
      when(() => salvarConfig(any())).thenAnswer(
        (invocation) async =>
            Right(invocation.positionalArguments.single as EmpresaConfig),
      );

      await provider.salvar(_dados);

      final enviada =
          verify(() => salvarConfig(captureAny())).captured.single
              as EmpresaConfig;
      expect(enviada.nome, 'Barbearia Nova');
      expect(enviada.telefone, '19988887777');
      expect(enviada.numero, '12');
      // o que o formulário não edita continua
      expect(enviada.cep, '13604512');
      expect(enviada.cidade, 'Araras');
      expect(provider.salvo, isTrue);
      expect(negocio.nome, 'Barbearia Nova');
    },
  );

  test('erro de validação da API vira a mensagem do campo', () async {
    when(() => salvarConfig(any())).thenAnswer(
      (_) async => const Left(
        ValidationFailure(
          fields: {
            'documento': ['CPF inválido.'],
          },
        ),
      ),
    );

    await provider.salvar(_dados);

    expect(provider.salvo, isFalse);
    expect(provider.errorMessage, 'CPF inválido.');
    expect(negocio.nome, 'Barbearia Demo');
  });

  test('CEP encontrado troca o endereço; não encontrado limpa', () async {
    when(() => buscarCep('01001000')).thenAnswer(
      (_) async => const Right(
        Endereco(
          cep: '01001000',
          endereco: 'Praça da Sé',
          cidade: 'São Paulo',
          uf: 'SP',
        ),
      ),
    );
    when(() => buscarCep('00000000')).thenAnswer(
      (_) async => const Left(NotFoundFailure(message: 'CEP não encontrado.')),
    );

    await provider.buscarCep('01001000');
    expect(provider.config.cidade, 'São Paulo');
    expect(provider.cepErrorMessage, isNull);

    await provider.buscarCep('00000000');
    expect(provider.config.endereco, '');
    expect(provider.cepErrorMessage, 'CEP não encontrado.');
  });
}
