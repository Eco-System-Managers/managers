import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/empresa/domain/entities/endereco.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_endereco_por_cep_use_case.dart';

import '../../domain/entities/cliente.dart';
import '../../domain/usecases/atualizar_cliente_use_case.dart';
import '../../domain/usecases/criar_cliente_use_case.dart';
import '../../domain/usecases/obter_cliente_use_case.dart';

// estado do formulário de cliente (montado em clientes_provider.dart, na
// raiz da feature): novo quando o id é null, edição quando não é. a busca
// de CEP é a mesma da empresa (ViaCEP, no core)
class ClienteFormProvider extends ChangeNotifier {
  ClienteFormProvider({
    required this.id,
    required this._obter,
    required this._criar,
    required this._atualizar,
    required this._buscarEnderecoPorCep,
  });

  // null = cliente novo
  final int? id;

  final ObterClienteUseCase _obter;
  final CriarClienteUseCase _criar;
  final AtualizarClienteUseCase _atualizar;
  final BuscarEnderecoPorCepUseCase _buscarEnderecoPorCep;

  Cliente? _cliente;
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  bool _salvo = false;

  // a busca de CEP tem loading e erro próprios
  bool _buscandoCep = false;
  String? _cepErrorMessage;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  bool get ehNovo => id == null;

  // null enquanto carrega ou quando é novo
  Cliente? get cliente => _cliente;
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro que não é de campo (rede, regra sem campo)
  String? get errorMessage => _errorMessage;

  // erro de validação da API, campo a campo, com os nomes do contrato
  // (nome, telefone, email, cpf, data_nascimento, cep...)
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  bool get buscandoCep => _buscandoCep;
  String? get cepErrorMessage => _cepErrorMessage;

  // true depois de salvar: a tela fecha
  bool get salvo => _salvo;

  Future<void> carregar() async {
    final id = this.id;
    if (id == null) {
      _carregado = true;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final result = await _obter(id);
    if (_disposed) return;

    result.fold((failure) => _erroAoCarregar = failure, (c) {
      _cliente = c;
      _carregado = true;
    });

    _isLoading = false;
    notifyListeners();
  }

  // devolve o endereço achado, para a tela preencher o campo; null quando
  // não achou (o erro fica em cepErrorMessage)
  Future<Endereco?> buscarCep(String cep) async {
    _buscandoCep = true;
    _cepErrorMessage = null;
    notifyListeners();

    final result = await _buscarEnderecoPorCep(cep);
    if (_disposed) return null;

    final endereco = result.fold((failure) {
      _cepErrorMessage = failure.message;
      return null;
    }, (e) => e);

    _buscandoCep = false;
    notifyListeners();
    return endereco;
  }

  // a tela entrega o cliente montado a partir dos campos, já validados
  Future<void> salvar(Cliente dados) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    final id = this.id;
    final result = id == null
        ? await _criar(dados)
        : await _atualizar(dados.copyWith(id: id));
    if (_disposed) return;

    result.fold(
      (failure) {
        if (failure is ValidationFailure && failure.fields.isNotEmpty) {
          _fieldErrors = {
            for (final e in failure.fields.entries)
              if (e.value.isNotEmpty) e.key: e.value.first,
          };
        } else {
          _errorMessage = failure.message;
        }
      },
      (salvo) {
        _cliente = salvo;
        _salvo = true;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  // a pessoa mexeu no campo: o erro que a API apontou nele não vale mais
  void limparErroDoCampo(String campo) {
    if (!_fieldErrors.containsKey(campo)) return;
    _fieldErrors = {..._fieldErrors}..remove(campo);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
