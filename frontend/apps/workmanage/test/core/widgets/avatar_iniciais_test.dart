import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/widgets/avatar_iniciais.dart';

void main() {
  test('iniciais pegam o primeiro e o último nome', () {
    expect(AvatarIniciais.iniciais('Ana Silva'), 'AS');
    expect(AvatarIniciais.iniciais('Ana Maria de Souza'), 'AS');
    expect(AvatarIniciais.iniciais('ana'), 'A');
    expect(AvatarIniciais.iniciais('  '), '?');
  });
}
