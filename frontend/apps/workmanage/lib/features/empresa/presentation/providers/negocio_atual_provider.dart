import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/buscar_meu_perfil_use_case.dart';

import '../../domain/entities/empresa_config.dart';
import '../../domain/usecases/buscar_config_use_case.dart';

// o negócio de quem está logado, para o app inteiro: a config (modo de
// agenda, nome, logo) e o papel da pessoa. o shell decide as abas por aqui,
// e serviços e configurações escondem a escrita de quem não é proprietário.
// carrega uma vez depois do login e zera quando a sessão acaba
class NegocioAtualProvider extends ChangeNotifier {
  NegocioAtualProvider({
    required this._buscarConfig,
    required this._buscarMeuPerfil,
  });

  final BuscarConfigUseCase _buscarConfig;
  final BuscarMeuPerfilUseCase _buscarMeuPerfil;

  EmpresaConfig? _config;
  Colaborador? _perfil;
  bool _carregando = false;
  Failure? _erro;
  bool _disposed = false;

  EmpresaConfig? get config => _config;
  Colaborador? get perfil => _perfil;
  bool get carregando => _carregando;
  Failure? get erro => _erro;
  bool get carregado => _config != null;

  TipoAgenda get tipoAgenda => _config?.tipoAgenda ?? TipoAgenda.horario;
  bool get isKanban => tipoAgenda == TipoAgenda.kanban;
  String get nome => _config?.nome ?? '';
  String get logoUrl => _config?.logoUrl ?? '';

  // só o proprietário escreve. sem perfil (404 sem_colaborador), trata como
  // colaborador: esconder é mais seguro que mostrar um botão que a API
  // vai recusar
  bool get ehProprietario => _perfil?.ehProprietario ?? false;

  Future<void> carregar({bool forcar = false}) async {
    if (_carregando || (carregado && !forcar)) return;
    _carregando = true;
    _erro = null;
    notifyListeners();

    final (config, perfil) = await (
      _buscarConfig(NoParams()),
      _buscarMeuPerfil(NoParams()),
    ).wait;
    if (_disposed) return;

    config.fold((failure) => _erro = failure, (c) => _config = c);
    // o perfil pode faltar (onboarding de antes da regra do colaborador):
    // segue sem papel. outra falha vale como erro da tela
    perfil.fold((failure) {
      _perfil = null;
      if (failure is! NotFoundFailure) _erro ??= failure;
    }, (p) => _perfil = p);

    _carregando = false;
    notifyListeners();
  }

  // as configurações salvaram: o resto do app enxerga na hora
  void atualizarConfig(EmpresaConfig config) {
    _config = config;
    notifyListeners();
  }

  // a sessão acabou: nada daqui pertence à próxima pessoa que entrar
  void limpar() {
    if (_config == null && _perfil == null && _erro == null) return;
    _config = null;
    _perfil = null;
    _erro = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
