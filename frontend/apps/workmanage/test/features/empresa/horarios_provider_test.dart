import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/empresa/domain/entities/empresa_config.dart';
import 'package:managers/features/empresa/domain/entities/horario_funcionamento.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_config_use_case.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_horarios_use_case.dart';
import 'package:managers/features/empresa/domain/usecases/salvar_horarios_use_case.dart';
import 'package:managers/features/empresa/presentation/providers/horarios_provider.dart';
import 'package:managers/features/empresa/presentation/providers/negocio_atual_provider.dart';
import 'package:managers/features/usuarios/domain/usecases/buscar_meu_perfil_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockBuscarHorarios extends Mock implements BuscarHorariosUseCase {}

class _MockSalvarHorarios extends Mock implements SalvarHorariosUseCase {}

class _MockBuscarConfig extends Mock implements BuscarConfigUseCase {}

class _MockBuscarMeuPerfil extends Mock implements BuscarMeuPerfilUseCase {}

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
  late _MockBuscarHorarios buscarHorarios;
  late _MockSalvarHorarios salvarHorarios;
  late NegocioAtualProvider negocio;
  late HorariosProvider provider;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(<HorarioFuncionamento>[]);
  });

  setUp(() {
    buscarHorarios = _MockBuscarHorarios();
    salvarHorarios = _MockSalvarHorarios();
    negocio = NegocioAtualProvider(
      buscarConfig: _MockBuscarConfig(),
      buscarMeuPerfil: _MockBuscarMeuPerfil(),
    )..atualizarConfig(const EmpresaConfig(tipoAgenda: TipoAgenda.horario));
    provider = HorariosProvider(
      negocio: negocio,
      buscarHorarios: buscarHorarios,
      salvarHorarios: salvarHorarios,
    );
    when(() => buscarHorarios(any())).thenAnswer((_) async => Right(_semana));
    when(() => salvarHorarios(any())).thenAnswer(
      (invocation) async => Right(
        invocation.positionalArguments.single as List<HorarioFuncionamento>,
      ),
    );
  });

  test('carrega a semana', () async {
    await provider.carregar();

    expect(provider.carregado, isTrue);
    expect(provider.horarios.length, 7);
    expect(provider.isKanban, isFalse);
  });

  test('falha ao carregar guarda o erro para a tela tentar de novo', () async {
    when(() => buscarHorarios(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));

    await provider.carregar();

    expect(provider.carregado, isFalse);
    expect(provider.erroAoCarregar, isA<NetworkFailure>());
  });

  test('não salva a semana sem nenhum dia aberto', () async {
    await provider.carregar();
    for (final h in provider.horarios) {
      provider.atualizarHorario(h.copyWith(ativo: false));
    }

    await provider.salvar();

    expect(provider.errorMessage, 'Abra pelo menos um dia da semana');
    verifyNever(() => salvarHorarios(any()));
  });

  test('aponta o dia aberto sem horário', () async {
    await provider.carregar();
    provider.atualizarHorario(
      const HorarioFuncionamento(dia: DiaSemana.segunda, ativo: true),
    );

    expect(
      provider.erroDoDia(provider.horarios.first),
      'Informe a abertura e o fechamento',
    );
    await provider.salvar();
    expect(provider.errorMessage, 'Corrija os horários marcados');
  });

  test('salva a semana válida e fecha', () async {
    await provider.carregar();
    provider.atualizarHorario(
      _semana.first.copyWith(fechamento: const HoraDoDia(19, 0)),
    );

    await provider.salvar();

    final enviados =
        verify(() => salvarHorarios(captureAny())).captured.single
            as List<HorarioFuncionamento>;
    expect(enviados.first.fechamento?.emMinutos, 19 * 60);
    expect(provider.salvo, isTrue);
  });

  test('na agenda kanban, dia aberto precisa de capacidade', () async {
    negocio.atualizarConfig(const EmpresaConfig(tipoAgenda: TipoAgenda.kanban));
    await provider.carregar();

    expect(provider.isKanban, isTrue);
    expect(
      provider.erroDoDia(provider.horarios.first),
      'Informe quantos atendimentos cabem no dia',
    );
  });
}
