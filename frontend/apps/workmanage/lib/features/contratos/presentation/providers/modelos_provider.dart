import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/empresa/presentation/providers/negocio_atual_provider.dart';

import '../../domain/entities/modelo_contrato.dart';
import '../../domain/usecases/modelos_use_cases.dart';

// estado da lista de modelos (montado em contratos_provider.dart, na raiz
// da feature): filtro de inativos e inativar/reativar. depois de qualquer
// escrita a lista é recarregada da API, nunca ajustada na mão
class ModelosProvider extends ChangeNotifier {
  ModelosProvider({
    required this._listar,
    required this._alterarAtivo,
    required this._negocio,
  });

  final ListarModelosUseCase _listar;
  final AlterarAtivoModeloUseCase _alterarAtivo;
  final NegocioAtualProvider _negocio;

  List<ModeloContrato> _modelos = [];
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  bool _mostrarInativos = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  List<ModeloContrato> get modelos => List.unmodifiable(_modelos);
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro de uma ação (inativar, reativar); a lista continua na tela
  String? get errorMessage => _errorMessage;
  bool get mostrarInativos => _mostrarInativos;

  // só o proprietário cria, edita e inativa modelo
  bool get ehProprietario => _negocio.ehProprietario;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final result = await _listar(
      // sem o filtro a API devolve todos; com ele, só os ativos
      ListarModelosParams(ativo: _mostrarInativos ? null : true),
    );
    if (_disposed) return;

    result.fold((failure) => _erroAoCarregar = failure, (modelos) {
      _modelos = modelos;
      _carregado = true;
    });

    _isLoading = false;
    notifyListeners();
  }

  Future<void> alternarInativos(bool mostrar) {
    _mostrarInativos = mostrar;
    return carregar();
  }

  Future<void> alterarAtivo(ModeloContrato modelo, bool ativo) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    final result = await _alterarAtivo(
      AlterarAtivoModeloParams(id: modelo.id, ativo: ativo),
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
