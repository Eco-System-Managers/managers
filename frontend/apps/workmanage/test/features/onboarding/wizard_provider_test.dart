import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/empresa/domain/entities/empresa_config.dart';
import 'package:managers/features/empresa/domain/entities/endereco.dart';
import 'package:managers/features/empresa/domain/entities/horario_funcionamento.dart';
import 'package:managers/features/empresa/domain/entities/nicho.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_config_use_case.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_endereco_por_cep_use_case.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_horarios_use_case.dart';
import 'package:managers/features/empresa/domain/usecases/concluir_onboarding_use_case.dart';
import 'package:managers/features/empresa/domain/usecases/salvar_config_use_case.dart';
import 'package:managers/features/empresa/domain/usecases/salvar_horarios_use_case.dart';
import 'package:managers/features/onboarding/presentation/providers/wizard_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockBuscarConfig extends Mock implements BuscarConfigUseCase {}

class _MockSalvarConfig extends Mock implements SalvarConfigUseCase {}

class _MockBuscarCep extends Mock implements BuscarEnderecoPorCepUseCase {}

class _MockBuscarHorarios extends Mock implements BuscarHorariosUseCase {}

class _MockSalvarHorarios extends Mock implements SalvarHorariosUseCase {}

class _MockConcluir extends Mock implements ConcluirOnboardingUseCase {}

const _configCompleta = EmpresaConfig(
  nome: 'Barbearia Central',
  documento: '11222333000181',
  tipoDocumento: TipoDocumento.cnpj,
  cep: '13604512',
  endereco: 'Rua Um',
  cidade: 'Araras',
  uf: 'SP',
  nichos: [Nicho.barbearia],
);

final _semana = [
  for (final dia in DiaSemana.values)
    HorarioFuncionamento(
      dia: dia,
      ativo: dia != DiaSemana.domingo,
      abertura: const HoraDoDia(9, 0),
      fechamento: const HoraDoDia(18, 0),
    ),
];

void main() {
  late _MockBuscarConfig buscarConfig;
  late _MockSalvarConfig salvarConfig;
  late _MockBuscarCep buscarCep;
  late _MockBuscarHorarios buscarHorarios;
  late _MockSalvarHorarios salvarHorarios;
  late _MockConcluir concluir;
  late WizardProvider wizard;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(const EmpresaConfig());
    registerFallbackValue(<HorarioFuncionamento>[]);
  });

  setUp(() {
    buscarConfig = _MockBuscarConfig();
    salvarConfig = _MockSalvarConfig();
    buscarCep = _MockBuscarCep();
    buscarHorarios = _MockBuscarHorarios();
    salvarHorarios = _MockSalvarHorarios();
    concluir = _MockConcluir();
    wizard = WizardProvider(
      buscarConfig: buscarConfig,
      salvarConfig: salvarConfig,
      buscarEnderecoPorCep: buscarCep,
      buscarHorarios: buscarHorarios,
      salvarHorarios: salvarHorarios,
      concluirOnboarding: concluir,
    );
    when(() => buscarHorarios(any())).thenAnswer((_) async => Right(_semana));
  });

  group('carregar', () {
    test('config vazia abre na etapa do negócio', () async {
      when(() => buscarConfig(any()))
          .thenAnswer((_) async => const Right(EmpresaConfig()));

      await wizard.carregar();

      expect(wizard.carregado, isTrue);
      expect(wizard.step, WizardStep.negocio);
      expect(wizard.horarios.length, 7);
    });

    test('config com documento e CEP mas sem nicho abre no nicho', () async {
      when(() => buscarConfig(any())).thenAnswer(
        (_) async => const Right(
          EmpresaConfig(
            nome: 'Barbearia Central',
            documento: '11222333000181',
            tipoDocumento: TipoDocumento.cnpj,
            cep: '13604512',
          ),
        ),
      );

      await wizard.carregar();

      expect(wizard.step, WizardStep.nicho);
    });

    test('config com nicho abre nos horários', () async {
      when(() => buscarConfig(any()))
          .thenAnswer((_) async => const Right(_configCompleta));

      await wizard.carregar();

      expect(wizard.step, WizardStep.horarios);
    });

    test('config com onboarding concluído vai direto ao fim', () async {
      when(() => buscarConfig(any())).thenAnswer(
        (_) async => Right(_configCompleta.copyWith(onboardingConcluido: true)),
      );

      await wizard.carregar();

      expect(wizard.step, WizardStep.concluido);
    });

    test('falha ao carregar guarda a mensagem e não marca carregado', () async {
      when(() => buscarConfig(any()))
          .thenAnswer((_) async => const Left(NetworkFailure()));

      await wizard.carregar();

      expect(wizard.carregado, isFalse);
      expect(wizard.errorMessage, 'Não foi possível conectar ao servidor.');
      verifyNever(() => buscarHorarios(any()));
    });
  });

  group('CEP', () {
    test('CEP encontrado preenche endereço, cidade e UF', () async {
      when(() => buscarCep('13604512')).thenAnswer(
        (_) async => const Right(
          Endereco(
            cep: '13604512',
            endereco: 'Rua Um',
            cidade: 'Araras',
            uf: 'SP',
          ),
        ),
      );

      await wizard.buscarCep('13604512');

      expect(wizard.temEndereco, isTrue);
      expect(wizard.config.cidade, 'Araras');
      expect(wizard.cepErrorMessage, isNull);
      expect(wizard.buscandoCep, isFalse);
    });

    test('CEP não encontrado limpa o endereço e guarda o erro', () async {
      when(() => buscarCep(any())).thenAnswer(
        (_) async => const Left(
          NotFoundFailure(
            message: 'CEP não encontrado.',
            code: 'cep_nao_encontrado',
          ),
        ),
      );

      await wizard.buscarCep('00000000');

      expect(wizard.temEndereco, isFalse);
      expect(wizard.cepErrorMessage, 'CEP não encontrado.');
    });
  });

  group('etapas', () {
    test('salvar o negócio guarda só os dígitos e avança', () async {
      when(() => salvarConfig(any()))
          .thenAnswer((_) async => const Right(_configCompleta));

      await wizard.salvarNegocio(
        nome: ' Barbearia Central ',
        telefone: '(19) 99999-0000',
        tipoDocumento: TipoDocumento.cnpj,
        documento: '11.222.333/0001-81',
        numero: '10',
      );

      final enviada =
          verify(() => salvarConfig(captureAny())).captured.single
              as EmpresaConfig;
      expect(enviada.nome, 'Barbearia Central');
      expect(enviada.telefone, '19999990000');
      expect(enviada.documento, '11222333000181');
      expect(enviada.numero, '10');
      expect(wizard.step, WizardStep.nicho);
    });

    test('erro de validação da API mostra a mensagem do campo', () async {
      when(() => salvarConfig(any())).thenAnswer(
        (_) async => const Left(
          ValidationFailure(
            fields: {
              'documento': ['CNPJ inválido.'],
            },
          ),
        ),
      );

      await wizard.salvarNegocio(
        nome: 'x',
        telefone: '',
        tipoDocumento: TipoDocumento.cnpj,
        documento: '1',
        numero: '',
      );

      expect(wizard.errorMessage, 'CNPJ inválido.');
      expect(wizard.step, WizardStep.negocio);
    });

    test('sem nicho escolhido, próximo não salva', () async {
      await wizard.salvarNicho();

      expect(wizard.errorMessage, 'Escolha pelo menos 1 nicho');
      verifyNever(() => salvarConfig(any()));
    });

    test(
      'escolher o nicho e salvar leva aos horários com o modo da API',
      () async {
        when(() => salvarConfig(any())).thenAnswer(
          (_) async => Right(
            _configCompleta.copyWith(
              nichos: [Nicho.lavaRapido],
              tipoAgenda: TipoAgenda.kanban,
            ),
          ),
        );

        wizard.alternarNicho(Nicho.lavaRapido);
        await wizard.salvarNicho();

        expect(wizard.step, WizardStep.horarios);
        expect(wizard.isKanban, isTrue);
      },
    );

    test('marca até 4 nichos da mesma área e manda todos', () async {
      when(() => salvarConfig(any()))
          .thenAnswer((_) async => const Right(_configCompleta));

      for (final nicho in [
        Nicho.massagem,
        Nicho.manicure,
        Nicho.cilios,
        Nicho.pedicure,
        Nicho.maquiagem,
        Nicho.lavaRapido,
      ]) {
        wizard.alternarNicho(nicho);
      }
      await wizard.salvarNicho();

      // o 5º e o de outra área não entram; a ordem é a de exibição
      final enviada =
          verify(() => salvarConfig(captureAny())).captured.single
              as EmpresaConfig;
      expect(enviada.nichos, [
        Nicho.manicure,
        Nicho.pedicure,
        Nicho.cilios,
        Nicho.massagem,
      ]);
    });

    test('tocar de novo desmarca', () {
      wizard.alternarNicho(Nicho.manicure);
      wizard.alternarNicho(Nicho.manicure);

      expect(wizard.config.nichos, isEmpty);
    });
  });

  group('concluir', () {
    setUp(() async {
      when(() => buscarConfig(any()))
          .thenAnswer((_) async => const Right(_configCompleta));
      await wizard.carregar();
    });

    test('exige pelo menos um dia aberto', () async {
      for (final h in wizard.horarios) {
        wizard.atualizarHorario(h.copyWith(ativo: false));
      }

      await wizard.concluir();

      expect(wizard.errorMessage, 'Abra pelo menos um dia da semana');
      verifyNever(() => salvarHorarios(any()));
    });

    test('dia aberto sem horário é apontado', () async {
      wizard.atualizarHorario(
        const HorarioFuncionamento(dia: DiaSemana.segunda, ativo: true),
      );

      expect(
        wizard.erroDoHorario(wizard.horarios.first),
        'Informe a abertura e o fechamento',
      );
      await wizard.concluir();
      expect(wizard.errorMessage, 'Corrija os horários marcados');
    });

    test('salva os horários, conclui e chega ao fim', () async {
      when(() => salvarHorarios(any())).thenAnswer((_) async => Right(_semana));
      when(() => concluir(any())).thenAnswer(
        (_) async => Right(_configCompleta.copyWith(onboardingConcluido: true)),
      );

      await wizard.concluir();

      expect(wizard.step, WizardStep.concluido);
      expect(wizard.config.onboardingConcluido, isTrue);
      verify(() => salvarHorarios(any())).called(1);
    });

    test('se concluir falhar, fica nos horários com o detail da API', () async {
      when(() => salvarHorarios(any())).thenAnswer((_) async => Right(_semana));
      when(() => concluir(any())).thenAnswer(
        (_) async => const Left(
          ServerFailure(
            message: 'Informe o CPF ou o CNPJ do negócio.',
            code: 'documento_obrigatorio',
          ),
        ),
      );

      await wizard.concluir();

      expect(wizard.step, WizardStep.horarios);
      expect(wizard.errorMessage, 'Informe o CPF ou o CNPJ do negócio.');
    });
  });
}
