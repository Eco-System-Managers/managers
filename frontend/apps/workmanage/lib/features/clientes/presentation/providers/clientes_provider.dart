import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/cliente.dart';
import '../../domain/params/listar_clientes_params.dart';
import '../../domain/usecases/listar_clientes_use_case.dart';

// estado da lista de clientes (montado em clientes_provider.dart, na raiz
// da feature): busca e paginação. a primeira página substitui a lista; as
// seguintes são acrescentadas quando a tela chega ao fim
class ClientesProvider extends ChangeNotifier {
  ClientesProvider({required this._listar});

  final ListarClientesUseCase _listar;

  List<Cliente> _clientes = [];
  int _pagina = 1;
  int _total = 0;
  bool _temMais = false;
  String _busca = '';
  bool _carregado = false;
  bool _isLoading = false;
  bool _carregandoMais = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  List<Cliente> get clientes => List.unmodifiable(_clientes);
  int get total => _total;
  bool get temMais => _temMais;
  String get busca => _busca;
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  bool get carregandoMais => _carregandoMais;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro ao buscar a próxima página; a lista continua na tela
  String? get errorMessage => _errorMessage;

  ListarClientesParams _params(int pagina) => ListarClientesParams(
    pagina: pagina,
    busca: _busca.isEmpty ? null : _busca,
  );

  // primeira página: substitui o que estava na tela
  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    _errorMessage = null;
    notifyListeners();

    final result = await _listar(_params(1));
    if (_disposed) return;

    result.fold((failure) => _erroAoCarregar = failure, (pagina) {
      _clientes = pagina.itens;
      _pagina = 1;
      _total = pagina.total;
      _temMais = pagina.temMais;
      _carregado = true;
    });

    _isLoading = false;
    notifyListeners();
  }

  // próxima página: acrescenta ao fim
  Future<void> carregarMais() async {
    if (!_temMais || _carregandoMais || _isLoading) return;
    _carregandoMais = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _listar(_params(_pagina + 1));
    if (_disposed) return;

    result.fold((failure) => _errorMessage = failure.message, (pagina) {
      _clientes = [..._clientes, ...pagina.itens];
      _pagina++;
      _total = pagina.total;
      _temMais = pagina.temMais;
    });

    _carregandoMais = false;
    notifyListeners();
  }

  Future<void> buscar(String texto) {
    _busca = texto.trim();
    return carregar();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
