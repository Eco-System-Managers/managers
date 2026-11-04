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

  // só o proprietário mexe na estrutura do negócio. sem perfil (404
  // sem_colaborador), trata como colaborador: esconder é mais seguro que
  // mostrar um botão que a API vai recusar
  bool get ehProprietario => _perfil?.ehProprietario ?? false;

  // o vínculo de quem entrou. o dono também tem perfil (com o tipo padrão),
  // mas o papel manda; sem perfil, o menor acesso: colaborador comum
  bool get ehParceiro => !ehProprietario && (_perfil?.ehParceiro ?? false);
  bool get ehColaboradorComum => !ehProprietario && !ehParceiro;

  // o rótulo de quem entrou, para o Mais
  String get papelExibido => ehProprietario
      ? 'Proprietário'
      : ehParceiro
      ? 'Parceiro'
      : 'Colaborador';

  // ---- o que cada pessoa pode, pelo modo e pelo vínculo. a API trava do
  // lado dela; aqui só se esconde ----

  // na esteira a operação é do negócio inteiro: o parceiro toca o negócio
  // com o dono (serviços, contratos, caixa, capacidade do dia, fechar
  // horário). a estrutura (equipe, assinatura, horários, dados do negócio,
  // nichos e etapas) continua só do dono. na agenda, só o dono opera
  bool get operaComODono => ehProprietario || (isKanban && ehParceiro);

  // o colaborador comum da esteira só vê o quadro: move os cards, ajusta o
  // tempo e lê a ficha sem telefone nem valores
  bool get soMoveOsCards => isKanban && ehColaboradorComum;

  // dinheiro: na agenda, dono e parceiro (a API devolve a cada um só os
  // próprios números); na esteira, quem opera com o dono, e o caixa inteiro
  bool get veValores =>
      isKanban ? operaComODono : (_perfil?.veValores ?? false);

  // cobrar: na agenda, o colaborador comum só com a flag ligada; na esteira
  // a flag não pesa, e ele nunca cobra
  bool get podeCobrar => isKanban ? operaComODono : (_perfil?.cobra ?? false);

  // o catálogo e os modelos de contrato: escreve o dono e, na esteira, o
  // parceiro
  bool get podeEditarServicos => operaComODono;
  bool get podeEditarModelos => operaComODono;

  // o quadro: receber, remarcar, falta, excluir, o ajuste do dia e fechar
  // horário são de quem opera com o dono
  bool get podeReceber => operaComODono;
  bool get podeAjustarDia => operaComODono;
  bool get podeFecharHorario => operaComODono;

  // as abas e os itens do Mais que o colaborador comum da esteira não tem
  bool get veInicio => !soMoveOsCards;
  bool get veClientes => !soMoveOsCards;
  bool get veServicos => !soMoveOsCards;
  bool get veContratos => !soMoveOsCards;

  // a estrutura do negócio (equipe, configurações e etapas): na agenda abre
  // para todos, só para ler; na esteira é só do dono
  bool get veEstrutura => ehProprietario || !isKanban;

  // o botão de bloquear a agenda: dono e parceiro (o parceiro, na própria)
  bool get podeBloquear => ehProprietario || (_perfil?.ehParceiro ?? false);
  bool podeBloquearAgendaDe(int colaboradorId) =>
      _perfil?.bloqueiaAgendaDe(colaboradorId) ?? false;

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
