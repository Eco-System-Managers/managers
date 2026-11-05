import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/novidades/data/repositories/novidades_repository_impl.dart';
import 'package:managers/features/novidades/domain/entities/novidade.dart';
import 'package:managers/features/novidades/domain/usecases/buscar_novidades_use_case.dart';
import 'package:managers/features/novidades/domain/usecases/marcar_novidades_vistas_use_case.dart';
import 'package:managers/features/novidades/presentation/providers/novidades_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NovidadesRepositoryImpl repository;
  late NovidadesProvider provider;

  NovidadesProvider novoProvider() => NovidadesProvider(
    buscar: BuscarNovidadesUseCase(repository),
    marcarVistas: MarcarNovidadesVistasUseCase(repository),
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    repository = NovidadesRepositoryImpl(const FlutterSecureStorage());
    provider = novoProvider();
  });

  test('na agenda mostra todas, a principal primeiro, e marca vista', () async {
    final itens = await provider.paraMostrar(isKanban: false);

    expect(itens.map((n) => n.tipo), [
      TipoDeNovidade.variosServicos,
      TipoDeNovidade.tema,
    ]);
    expect(await repository.ultimaVista(), versaoDasNovidades);
  });

  test('na esteira não mostra o que é só da agenda', () async {
    final itens = await provider.paraMostrar(isKanban: true);

    expect(itens.map((n) => n.tipo), [TipoDeNovidade.tema]);
  });

  test('aparece uma vez só: a próxima abertura não mostra', () async {
    await provider.paraMostrar(isKanban: false);

    expect(await novoProvider().paraMostrar(isKanban: false), isEmpty);
  });

  test('na mesma casca não pergunta de novo', () async {
    await provider.paraMostrar(isKanban: false);
    await repository.marcarVista('outra');

    expect(await provider.paraMostrar(isKanban: false), isEmpty);
  });

  test('versão antiga vista mostra as desta versão', () async {
    await repository.marcarVista('1.0.0+1');

    expect(await provider.paraMostrar(isKanban: false), isNotEmpty);
  });
}
