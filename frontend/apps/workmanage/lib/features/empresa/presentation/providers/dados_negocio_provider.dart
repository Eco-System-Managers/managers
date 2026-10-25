import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/empresa_config.dart';
import '../../domain/usecases/buscar_endereco_por_cep_use_case.dart';
import '../../domain/usecases/salvar_config_use_case.dart';
import '../widgets/dados_negocio_form.dart';
import 'negocio_atual_provider.dart';

// estado da tela "Dados do negócio" das configurações (montado em
// empresa_provider.dart). abre com a config do negócio atual e, ao salvar,
// devolve a config nova para o resto do app
class DadosNegocioProvider extends ChangeNotifier {
  DadosNegocioProvider({
    required this._negocio,
    required this._salvarConfig,
    required this._buscarEnderecoPorCep,
  }) : _config = _negocio.config ?? const EmpresaConfig();

  final NegocioAtualProvider _negocio;
  final SalvarConfigUseCase _salvarConfig;
  final BuscarEnderecoPorCepUseCase _buscarEnderecoPorCep;

  EmpresaConfig _config;
  bool _isLoading = false;
  String? _errorMessage;
  bool _salvo = false;

  // a busca de CEP tem loading e erro próprios: ela roda no meio do
  // formulário e não pode travar nem sujar o resto da tela
  bool _buscandoCep = false;
  String? _cepErrorMessage;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  EmpresaConfig get config => _config;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get buscandoCep => _buscandoCep;
  String? get cepErrorMessage => _cepErrorMessage;

  // true depois de salvar: a tela fecha
  bool get salvo => _salvo;

  // chamado quando a pessoa termina de digitar o CEP
  Future<void> buscarCep(String cep) async {
    _buscandoCep = true;
    _cepErrorMessage = null;
    notifyListeners();

    final result = await _buscarEnderecoPorCep(cep);
    if (_disposed) return;

    result.fold(
      (failure) {
        _cepErrorMessage = failure.message;
        // o endereço antigo não vale para o CEP novo
        _config = _config.copyWith(endereco: '', cidade: '', uf: '');
      },
      (endereco) {
        _config = _config.copyWith(
          cep: endereco.cep,
          endereco: endereco.endereco,
          cidade: endereco.cidade,
          uf: endereco.uf,
        );
      },
    );

    _buscandoCep = false;
    notifyListeners();
  }

  // o CEP, o endereço, a cidade e a UF já estão na config
  Future<void> salvar(DadosNegocio dados) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _salvarConfig(
      _config.copyWith(
        nome: dados.nome,
        telefone: dados.telefone,
        tipoDocumento: dados.tipoDocumento,
        documento: dados.documento,
        numero: dados.numero,
      ),
    );
    if (_disposed) return;

    result.fold(
      (failure) {
        // erro de validação da API vira a mensagem do campo que falhou
        _errorMessage = failure is ValidationFailure
            ? failure.resumo
            : failure.message;
      },
      (salva) {
        _config = salva;
        _negocio.atualizarConfig(salva);
        _salvo = true;
      },
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
