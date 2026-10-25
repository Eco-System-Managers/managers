import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/session/sessao_secure_repository.dart';

import '../../helpers/fake_sessao_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessaoSecureRepository repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    repository = SessaoSecureRepository(const FlutterSecureStorage());
  });

  test('sem nada guardado, carregar devolve null', () async {
    expect(await repository.carregar(), isNull);
  });

  test('salvar e carregar devolvem a mesma sessão', () async {
    await repository.salvar(sessaoDeTeste);
    expect(await repository.carregar(), sessaoDeTeste);
  });

  test('limpar apaga a sessão', () async {
    await repository.salvar(sessaoDeTeste);
    await repository.limpar();
    expect(await repository.carregar(), isNull);
  });

  test('guardado corrompido vira "sem sessão" e é apagado', () async {
    FlutterSecureStorage.setMockInitialValues({'sessao': '{isso nao e json'});
    expect(await repository.carregar(), isNull);
    expect(await const FlutterSecureStorage().read(key: 'sessao'), isNull);
  });
}
