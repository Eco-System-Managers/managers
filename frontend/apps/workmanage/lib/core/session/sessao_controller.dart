import 'package:flutter/foundation.dart';

import 'sessao.dart';
import 'sessao_repository.dart';

// a sessão em memória, para o app inteiro: o interceptor lê o token daqui,
// o router decide por aqui se a tela pode abrir, e login e logout mudam
// aqui. persiste no SessaoRepository para sobreviver a fechar o app
class SessaoController extends ChangeNotifier {
  SessaoController(this._repository);

  final SessaoRepository _repository;

  Sessao? _atual;
  bool _carregada = false;

  Sessao? get atual => _atual;
  bool get autenticado => _atual != null;

  // false até o carregar() terminar: a splash espera por isto
  bool get carregada => _carregada;

  // na abertura do app: recupera o que ficou guardado
  Future<void> carregar() async {
    _atual = await _repository.carregar();
    _carregada = true;
    notifyListeners();
  }

  // login e cadastro confirmado
  Future<void> entrar(Sessao sessao) async {
    await _repository.salvar(sessao);
    _atual = sessao;
    notifyListeners();
  }

  // o interceptor renovou os tokens: troca sem a tela perceber (nada muda
  // para o router, então não notifica)
  Future<void> renovar(Sessao sessao) async {
    await _repository.salvar(sessao);
    _atual = sessao;
  }

  // logout, ou a API disse que a sessão acabou. o router escuta e leva
  // ao login se a tela aberta exigir sessão
  Future<void> sair() async {
    if (_atual == null) return;
    _atual = null;
    await _repository.limpar();
    notifyListeners();
  }
}
