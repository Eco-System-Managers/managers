import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import 'package:managers/core/usecases/use_case.dart';

import '../../domain/entities/colaborador.dart';
import '../../domain/entities/convite.dart';
import '../../domain/params/equipe_params.dart';
import '../../domain/usecases/equipe_use_cases.dart';

// estado da ficha de um colaborador (montado em usuarios_provider.dart, na
// raiz da feature): os dados (nome, função, vínculo, comissão, cobrar),
// convidar para o app (e o convite pendente: reenviar, cancelar, o link para
// o WhatsApp), ativar/desativar e remover. a API protege o proprietário
// (proprietario_protegido); a tela nem oferece
class ColaboradorProvider extends ChangeNotifier {
  ColaboradorProvider({
    required this.id,
    required this._obter,
    required this._atualizar,
    required this._convidar,
    required this._listarConvites,
    required this._cancelarConvite,
    required this._alterarAtivo,
    required this._contarPendentes,
    required this._remover,
  });

  final int id;
  final ObterColaboradorUseCase _obter;
  final AtualizarColaboradorUseCase _atualizar;
  final ConvidarColaboradorUseCase _convidar;
  final ListarConvitesUseCase _listarConvites;
  final CancelarConviteUseCase _cancelarConvite;
  final AlterarAtivoColaboradorUseCase _alterarAtivo;
  final ContarAgendamentosPendentesUseCase _contarPendentes;
  final RemoverColaboradorUseCase _remover;

  Colaborador? _colaborador;
  Convite? _convite;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  bool _salvo = false;
  bool _convidado = false;
  bool _removido = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  Colaborador? get colaborador => _colaborador;

  // o convite pendente desta pessoa; null sem convite (ou para quem não é
  // o dono: a API nega a lista, e a ficha segue sem ele)
  Convite? get convite => _convite;

  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro de uma ação; a ficha continua
  String? get errorMessage => _errorMessage;

  // erro de validação da API, campo a campo (nome, funcao,
  // comissao_percentual, email)
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  // true logo depois de salvar: a tela avisa e zera
  bool get salvo => _salvo;

  // true logo depois de convidar: a tela avisa e zera
  bool get convidado => _convidado;

  // true depois de remover: a tela fecha
  bool get removido => _removido;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final (result, convites) = await (
      _obter(id),
      _listarConvites(NoParams()),
    ).wait;
    if (_disposed) return;

    result.fold(
      (failure) => _erroAoCarregar = failure,
      (c) => _colaborador = c,
    );
    convites.fold(
      (_) {},
      (lista) =>
          _convite = lista.where((c) => c.colaboradorId == id).firstOrNull,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> salvar(DadosColaborador dados) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    _salvo = false;
    notifyListeners();

    final result = await _atualizar(
      AtualizarColaboradorParams(id: id, dados: dados),
    );
    if (_disposed) return;

    result.fold(_guardarFalha, (c) {
      _colaborador = c;
      _salvo = true;
    });

    _isLoading = false;
    notifyListeners();
  }

  // dar login a quem está na equipe sem acesso: a API manda o e-mail
  Future<void> convidar(String email) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    _convidado = false;
    notifyListeners();

    final result = await _convidar(
      ConvidarColaboradorParams(id: id, email: email.trim()),
    );
    if (_disposed) return;

    result.fold(_guardarFalha, (convite) {
      _convite = convite;
      _convidado = true;
    });

    _isLoading = false;
    notifyListeners();
  }

  // o e-mail não chegou: cancela o pendente e manda outro para o mesmo
  // endereço (a API recusa um segundo convite enquanto há um pendente)
  Future<void> reenviarConvite() async {
    final convite = _convite;
    if (convite == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final cancelado = await _cancelarConvite(convite.id);
    if (_disposed) return;
    final falha = cancelado.fold((f) => f, (_) => null);
    if (falha != null) {
      _errorMessage = falha.message;
      _isLoading = false;
      notifyListeners();
      return;
    }
    _convite = null;
    await convidar(convite.email);
  }

  Future<void> cancelarConvite() async {
    final convite = _convite;
    if (convite == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _cancelarConvite(convite.id);
    if (_disposed) return;

    result.fold((failure) => _errorMessage = failure.message, (_) {
      _convite = null;
    });

    _isLoading = false;
    notifyListeners();
  }

  void _guardarFalha(Failure failure) {
    if (failure is ValidationFailure && failure.fields.isNotEmpty) {
      _fieldErrors = {
        for (final e in failure.fields.entries)
          if (e.value.isNotEmpty) e.key: e.value.first,
      };
    } else {
      _errorMessage = failure.message;
    }
  }

  void limparErroDoCampo(String campo) {
    if (!_fieldErrors.containsKey(campo)) return;
    _fieldErrors = {..._fieldErrors}..remove(campo);
    notifyListeners();
  }

  void avisosMostrados() {
    _salvo = false;
    _convidado = false;
  }

  // desativar responde 204: a ficha vem da API de novo
  Future<void> alterarAtivo(bool ativo) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _alterarAtivo(
      AlterarAtivoColaboradorParams(id: id, ativo: ativo),
    );
    if (_disposed) return;

    await result.fold((failure) async {
      _errorMessage = failure.message;
      _isLoading = false;
      notifyListeners();
    }, (_) => carregar());
  }

  // quantos agendamentos futuros ficariam sem profissional; null quando a
  // consulta falhou (o erro fica em errorMessage)
  Future<int?> contarPendentes() async {
    final result = await _contarPendentes(id);
    if (_disposed) return null;
    return result.fold((failure) {
      _errorMessage = failure.message;
      notifyListeners();
      return null;
    }, (total) => total);
  }

  Future<void> remover() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _remover(id);
    if (_disposed) return;

    result.fold(
      (failure) => _errorMessage = failure.message,
      (_) => _removido = true,
    );

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
