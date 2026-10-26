import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../../domain/entities/colaborador.dart';
import '../../domain/entities/convite.dart';
import '../../domain/usecases/equipe_use_cases.dart';
import '../../domain/usecases/listar_colaboradores_use_case.dart';

// estado da tela da equipe (montado em usuarios_provider.dart, na raiz da
// feature): quem trabalha no negócio e os convites pendentes
class EquipeProvider extends ChangeNotifier {
  EquipeProvider({
    required this._listarColaboradores,
    required this._listarConvites,
    required this._cancelarConvite,
  });

  final ListarColaboradoresUseCase _listarColaboradores;
  final ListarConvitesUseCase _listarConvites;
  final CancelarConviteUseCase _cancelarConvite;

  List<Colaborador> _colaboradores = const [];
  List<Convite> _convites = const [];
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  List<Colaborador> get colaboradores => _colaboradores;

  // vazia para quem não é proprietário (a API nega a lista)
  List<Convite> get convites => _convites;

  // o convite pendente de alguém da equipe, para a linha dele
  Convite? conviteDe(int colaboradorId) =>
      _convites.where((c) => c.colaboradorId == colaboradorId).firstOrNull;

  // convites antigos, feitos sem a pessoa cadastrada: ficam numa lista à
  // parte até serem aceitos ou cancelados
  List<Convite> get convitesSoltos =>
      _convites.where((c) => c.colaboradorId == null).toList();

  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro de uma ação; a lista continua
  String? get errorMessage => _errorMessage;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final (colaboradores, convites) = await (
      _listarColaboradores(NoParams()),
      _listarConvites(NoParams()),
    ).wait;
    if (_disposed) return;

    colaboradores.fold((failure) => _erroAoCarregar = failure, (lista) {
      _colaboradores = lista;
      _carregado = true;
    });
    // os convites falhando (403 para colaborador) não derrubam a tela
    convites.fold((_) => _convites = const [], (lista) => _convites = lista);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> cancelarConvite(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _cancelarConvite(id);
    if (_disposed) return;

    await result.fold((failure) async {
      _errorMessage = failure.message;
      _isLoading = false;
      notifyListeners();
    }, (_) => carregar());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
