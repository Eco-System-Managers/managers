import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/tema/preferencia_de_tema.dart';
import 'package:managers/core/tema/tema_controller.dart';
import 'package:managers/core/tema/tema_repository.dart';

class _RepositoryFalso implements TemaRepository {
  _RepositoryFalso([this.guardado = PreferenciaDeTema.sistema]);

  PreferenciaDeTema guardado;
  bool falhaAoSalvar = false;
  int salvamentos = 0;

  @override
  Future<PreferenciaDeTema> carregar() async => guardado;

  @override
  Future<void> salvar(PreferenciaDeTema preferencia) async {
    salvamentos++;
    if (falhaAoSalvar) throw Exception('sem armazenamento');
    guardado = preferencia;
  }
}

void main() {
  test('começa no tema do aparelho e carrega o que estava guardado', () async {
    final controller = TemaController(
      _RepositoryFalso(PreferenciaDeTema.escuro),
    );
    var avisos = 0;
    controller.addListener(() => avisos++);

    expect(controller.preferencia, PreferenciaDeTema.sistema);
    await controller.carregar();

    expect(controller.preferencia, PreferenciaDeTema.escuro);
    expect(avisos, 1);
  });

  test('escolher troca na hora, avisa e guarda', () async {
    final repository = _RepositoryFalso();
    final controller = TemaController(repository);
    var avisos = 0;
    controller.addListener(() => avisos++);

    await controller.escolher(PreferenciaDeTema.claro);

    expect(controller.preferencia, PreferenciaDeTema.claro);
    expect(avisos, 1);
    expect(repository.guardado, PreferenciaDeTema.claro);
  });

  test('escolher o que já está escolhido não faz nada', () async {
    final repository = _RepositoryFalso();
    final controller = TemaController(repository);
    var avisos = 0;
    controller.addListener(() => avisos++);

    await controller.escolher(PreferenciaDeTema.sistema);

    expect(avisos, 0);
    expect(repository.salvamentos, 0);
  });

  test('se guardar falhar, o tema muda mesmo assim e não estoura', () async {
    final repository = _RepositoryFalso()..falhaAoSalvar = true;
    final controller = TemaController(repository);

    await controller.escolher(PreferenciaDeTema.escuro);

    expect(controller.preferencia, PreferenciaDeTema.escuro);
    expect(repository.guardado, PreferenciaDeTema.sistema);
  });
}
