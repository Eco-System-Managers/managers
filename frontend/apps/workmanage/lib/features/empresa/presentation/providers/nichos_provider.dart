import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/servicos/domain/params/listar_servicos_params.dart';
import 'package:managers/features/servicos/domain/usecases/listar_servicos_use_case.dart';

import '../../domain/entities/empresa_config.dart';
import '../../domain/entities/nicho.dart';
import '../../domain/usecases/salvar_config_use_case.dart';
import 'negocio_atual_provider.dart';

// estado da tela "Nichos" das configurações (montado em
// empresa_provider.dart). abre com os nichos do negócio; só a área dele
// pode ser escolhida, porque o modo de agenda trava no onboarding. tirar um
// nicho inativa os serviços dele (a API faz isso ao salvar), então a tela
// conta quantos são e pede confirmação antes
class NichosProvider extends ChangeNotifier {
  NichosProvider({
    required this._negocio,
    required this._salvarConfig,
    required this._listarServicos,
  }) : _originais = _negocio.config?.nichos ?? const [],
       _escolhidos = _negocio.config?.nichos ?? const [];

  final NegocioAtualProvider _negocio;
  final SalvarConfigUseCase _salvarConfig;
  final ListarServicosUseCase _listarServicos;

  final List<Nicho> _originais;
  List<Nicho> _escolhidos;
  bool _isLoading = false;
  String? _errorMessage;
  bool _salvo = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  List<Nicho> get escolhidos => List.unmodifiable(_escolhidos);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // true depois de salvar: a tela fecha
  bool get salvo => _salvo;

  // a área não muda depois do onboarding: a grade mostra só ela
  AreaNicho? get area => _negocio.config?.area;

  // os que estavam marcados e saíram: os serviços deles serão inativados
  List<Nicho> get removidos => [
    for (final n in _originais)
      if (!_escolhidos.contains(n)) n,
  ];

  bool get mudou => !listEquals(_originais, _escolhidos);

  // pelo menos 1 nicho, e alguma mudança para salvar
  bool get podeSalvar => _escolhidos.isNotEmpty && mudou && !_isLoading;

  void alternar(Nicho nicho) {
    _escolhidos = _escolhidos.alternar(nicho);
    _errorMessage = null;
    notifyListeners();
  }

  // quantos serviços ativos estão nos nichos que saíram. null quando a
  // contagem falhou: a mensagem fica na tela e nada é salvo
  Future<int?> contarServicosAfetados() async {
    final removidos = this.removidos;
    if (removidos.isEmpty) return 0;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _listarServicos(
      const ListarServicosParams(ativo: true),
    );
    if (_disposed) return null;

    final total = result.fold<int?>((failure) {
      _errorMessage = failure.message;
      return null;
    }, (servicos) => servicos.where((s) => removidos.contains(s.nicho)).length);

    _isLoading = false;
    notifyListeners();
    return total;
  }

  Future<void> salvar() async {
    final config = _negocio.config ?? const EmpresaConfig();

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _salvarConfig(config.copyWith(nichos: _escolhidos));
    if (_disposed) return;

    result.fold(
      (failure) {
        _errorMessage = failure is ValidationFailure
            ? failure.resumo
            : failure.message;
      },
      (salva) {
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
