import 'preferencia_de_tema.dart';

// onde a escolha do tema fica guardada entre uma abertura e outra do app.
// quem usa é o TemaController; as telas nunca falam com isto direto
abstract class TemaRepository {
  // sistema quando nada foi escolhido
  Future<PreferenciaDeTema> carregar();

  Future<void> salvar(PreferenciaDeTema preferencia);
}
