import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/tema/preferencia_de_tema.dart';
import 'package:managers/core/tema/tema_secure_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TemaSecureRepository repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    repository = TemaSecureRepository(const FlutterSecureStorage());
  });

  test('sem nada guardado, o tema é o do aparelho', () async {
    expect(await repository.carregar(), PreferenciaDeTema.sistema);
  });

  test('salvar e carregar devolvem a mesma escolha', () async {
    await repository.salvar(PreferenciaDeTema.escuro);
    expect(await repository.carregar(), PreferenciaDeTema.escuro);

    await repository.salvar(PreferenciaDeTema.claro);
    expect(await repository.carregar(), PreferenciaDeTema.claro);
  });

  test('um valor que o app não conhece vira o tema do aparelho', () async {
    FlutterSecureStorage.setMockInitialValues({'tema': 'roxo'});
    expect(await repository.carregar(), PreferenciaDeTema.sistema);
  });
}
