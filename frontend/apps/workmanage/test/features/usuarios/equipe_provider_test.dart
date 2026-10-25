import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/entities/convite.dart';
import 'package:managers/features/usuarios/domain/usecases/equipe_use_cases.dart';
import 'package:managers/features/usuarios/domain/usecases/listar_colaboradores_use_case.dart';
import 'package:managers/features/usuarios/presentation/providers/equipe_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockListarColaboradores extends Mock
    implements ListarColaboradoresUseCase {}

class _MockListarConvites extends Mock implements ListarConvitesUseCase {}

class _MockCancelarConvite extends Mock implements CancelarConviteUseCase {}

const _dono = Colaborador(
  id: 1,
  nome: 'Dono',
  email: 'dono@demo.com',
  papel: Papel.proprietario,
);
const _bia = Colaborador(id: 2, nome: 'Bia', email: 'bia@demo.com');

final _convite = Convite(
  id: 5,
  nome: 'Caio',
  email: 'caio@demo.com',
  aceito: false,
  criadoEm: DateTime(2026, 10, 25),
  expiraEm: DateTime(2026, 10, 27),
);

void main() {
  late _MockListarColaboradores listarColaboradores;
  late _MockListarConvites listarConvites;
  late _MockCancelarConvite cancelarConvite;

  setUpAll(() => registerFallbackValue(NoParams()));

  EquipeProvider montar() => EquipeProvider(
    listarColaboradores: listarColaboradores,
    listarConvites: listarConvites,
    cancelarConvite: cancelarConvite,
  );

  setUp(() {
    listarColaboradores = _MockListarColaboradores();
    listarConvites = _MockListarConvites();
    cancelarConvite = _MockCancelarConvite();
    when(() => listarColaboradores(any()))
        .thenAnswer((_) async => const Right([_dono, _bia]));
    when(() => listarConvites(any()))
        .thenAnswer((_) async => Right([_convite]));
  });

  test('carregar traz a equipe e os convites pendentes', () async {
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isTrue);
    expect(provider.colaboradores, [_dono, _bia]);
    expect(provider.convites, [_convite]);
  });

  test('convites negados (colaborador) não derrubam a tela', () async {
    when(() => listarConvites(any()))
        .thenAnswer((_) async => const Left(PermissionFailure()));
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isTrue);
    expect(provider.convites, isEmpty);
    expect(provider.erroAoCarregar, isNull);
  });

  test('erro na equipe vira erroAoCarregar', () async {
    when(() => listarColaboradores(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    final provider = montar();

    await provider.carregar();

    expect(provider.carregado, isFalse);
    expect(provider.erroAoCarregar, isA<NetworkFailure>());
  });

  test('cancelarConvite recarrega a lista; erro fica na tela', () async {
    when(() => cancelarConvite(5)).thenAnswer((_) async => const Right(null));
    final provider = montar();
    await provider.carregar();

    await provider.cancelarConvite(5);

    verify(() => cancelarConvite(5)).called(1);
    verify(() => listarConvites(any())).called(2);
    expect(provider.errorMessage, isNull);

    when(() => cancelarConvite(5))
        .thenAnswer((_) async => const Left(ServerFailure(message: 'Falhou.')));
    await provider.cancelarConvite(5);

    expect(provider.errorMessage, 'Falhou.');
    expect(provider.isLoading, isFalse);
  });
}
