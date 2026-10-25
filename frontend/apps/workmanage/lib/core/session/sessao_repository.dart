import 'sessao.dart';

// onde a sessão fica guardada entre uma abertura e outra do app.
// quem usa é o SessaoController; as telas nunca falam com isto direto
abstract class SessaoRepository {
  // null quando não há sessão guardada
  Future<Sessao?> carregar();

  Future<void> salvar(Sessao sessao);

  Future<void> limpar();
}
