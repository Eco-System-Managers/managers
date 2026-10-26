import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/clientes/domain/entities/cliente.dart';
import 'package:managers/features/clientes/domain/params/listar_clientes_params.dart';
import 'package:managers/features/clientes/domain/usecases/listar_clientes_use_case.dart';
import 'package:managers/features/clientes/domain/usecases/obter_cliente_use_case.dart';

import '../../domain/entities/contrato.dart';
import '../../domain/entities/modelo_contrato.dart';
import '../../domain/usecases/contratos_use_cases.dart';
import '../../domain/usecases/modelos_use_cases.dart';

// estado da geração de um contrato (montado em contratos_provider.dart, na
// raiz da feature): o modelo e o cliente escolhidos. vindo da ficha do
// cliente, ele já chega escolhido
class GerarContratoProvider extends ChangeNotifier {
  GerarContratoProvider({
    this.clienteInicialId,
    required this._listarModelos,
    required this._listarClientes,
    required this._obterCliente,
    required this._gerar,
  });

  final int? clienteInicialId;
  final ListarModelosUseCase _listarModelos;
  final ListarClientesUseCase _listarClientes;
  final ObterClienteUseCase _obterCliente;
  final GerarContratoUseCase _gerar;

  List<ModeloContrato> _modelos = [];
  ModeloContrato? _modelo;
  Cliente? _cliente;
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  Contrato? _gerado;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  // só os modelos ativos: inativo não gera contrato novo
  List<ModeloContrato> get modelos => List.unmodifiable(_modelos);
  ModeloContrato? get modelo => _modelo;
  Cliente? get cliente => _cliente;
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;
  String? get errorMessage => _errorMessage;

  // "modelo" e "cliente" quando faltam; o resto é o que a API apontar
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  // o contrato criado: a tela fecha e abre a ficha dele
  Contrato? get gerado => _gerado;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final inicial = clienteInicialId;
    final (modelos, cliente) = await (
      _listarModelos(const ListarModelosParams(ativo: true)),
      inicial == null ? Future.value(null) : _obterCliente(inicial),
    ).wait;
    if (_disposed) return;

    modelos.fold((failure) => _erroAoCarregar = failure, (lista) {
      _modelos = lista;
      // com um modelo só, não há o que escolher
      if (lista.length == 1) _modelo = lista.single;
    });
    cliente?.fold((failure) => _erroAoCarregar ??= failure, (c) {
      _cliente = c;
    });

    _carregado = _erroAoCarregar == null;
    _isLoading = false;
    notifyListeners();
  }

  void selecionarModelo(ModeloContrato modelo) {
    _modelo = modelo;
    _fieldErrors = {..._fieldErrors}..remove('modelo');
    notifyListeners();
  }

  void selecionarCliente(Cliente cliente) {
    _cliente = cliente;
    _fieldErrors = {..._fieldErrors}..remove('cliente');
    notifyListeners();
  }

  // a folha de escolher cliente busca na API enquanto a pessoa digita
  Future<List<Cliente>> buscarClientes(String busca) async {
    final result = await _listarClientes(ListarClientesParams(busca: busca));
    return result.fold((_) => const [], (pagina) => pagina.itens);
  }

  Future<void> gerar() async {
    final modelo = _modelo;
    final cliente = _cliente;
    _fieldErrors = {
      if (modelo == null) 'modelo': 'Escolha o modelo',
      if (cliente == null) 'cliente': 'Escolha o cliente',
    };
    if (modelo == null || cliente == null) {
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _gerar(
      GerarContratoParams(modeloId: modelo.id, clienteId: cliente.id),
    );
    if (_disposed) return;

    result.fold((failure) {
      if (failure is ValidationFailure && failure.fields.isNotEmpty) {
        _fieldErrors = {
          for (final e in failure.fields.entries)
            if (e.value.isNotEmpty) e.key: e.value.first,
        };
      } else {
        _errorMessage = failure.message;
      }
    }, (contrato) => _gerado = contrato);

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
