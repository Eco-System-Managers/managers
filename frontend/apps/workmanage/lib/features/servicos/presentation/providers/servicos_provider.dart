import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/empresa/presentation/providers/negocio_atual_provider.dart';

import '../../domain/entities/servico.dart';
import '../../domain/params/alterar_ativo_params.dart';
import '../../domain/params/listar_servicos_params.dart';
import '../../domain/usecases/alterar_ativo_servico_use_case.dart';
import '../../domain/usecases/listar_servicos_use_case.dart';

// estado da lista de serviços (montado em servicos_provider.dart, na raiz
// da feature): busca, filtro de inativos e inativar/reativar. depois de
// qualquer escrita a lista é recarregada da API, nunca ajustada na mão
class ServicosProvider extends ChangeNotifier {
  ServicosProvider({
    required this._listar,
    required this._alterarAtivo,
    required this._negocio,
  });

  final ListarServicosUseCase _listar;
  final AlterarAtivoServicoUseCase _alterarAtivo;
  final NegocioAtualProvider _negocio;

  List<Servico> _servicos = [];
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  String _busca = '';
  bool _mostrarInativos = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  List<Servico> get servicos => List.unmodifiable(_servicos);
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro de uma ação (inativar, reativar); a lista continua na tela
  String? get errorMessage => _errorMessage;
  String get busca => _busca;
  bool get mostrarInativos => _mostrarInativos;

  // só o proprietário cria, edita e inativa
  bool get ehProprietario => _negocio.ehProprietario;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final result = await _listar(
      ListarServicosParams(
        busca: _busca.isEmpty ? null : _busca,
        // sem o filtro a API devolve todos; com ele, só os ativos
        ativo: _mostrarInativos ? null : true,
      ),
    );
    if (_disposed) return;

    result.fold((failure) => _erroAoCarregar = failure, (servicos) {
      _servicos = servicos;
      _carregado = true;
    });

    _isLoading = false;
    notifyListeners();
  }

  Future<void> buscar(String texto) {
    _busca = texto.trim();
    return carregar();
  }

  Future<void> alternarInativos(bool mostrar) {
    _mostrarInativos = mostrar;
    return carregar();
  }

  Future<void> alterarAtivo(Servico servico, bool ativo) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    final result = await _alterarAtivo(
      AlterarAtivoParams(id: servico.id, ativo: ativo),
    );
    if (_disposed) return;

    final deuCerto = result.fold((failure) {
      _errorMessage = failure.message;
      return false;
    }, (_) => true);

    if (deuCerto) {
      await carregar();
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
