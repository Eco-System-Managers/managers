import 'package:flutter/foundation.dart';

import '../../domain/params/logo_params.dart';
import '../../domain/usecases/enviar_logo_use_case.dart';
import 'negocio_atual_provider.dart';

// estado da tela de configurações (montado em empresa_provider.dart): o menu
// das seções e a troca da logo. nome, nicho, modo e logo vêm do negócio
// atual, que é quem o resto do app enxerga
class ConfiguracoesProvider extends ChangeNotifier {
  ConfiguracoesProvider({required this._negocio, required this._enviarLogo});

  final NegocioAtualProvider _negocio;
  final EnviarLogoUseCase _enviarLogo;

  bool _enviandoLogo = false;
  String? _errorMessage;

  // a tela pode ser fechada durante o envio
  bool _disposed = false;

  bool get enviandoLogo => _enviandoLogo;
  String? get errorMessage => _errorMessage;

  // a imagem já vem em bytes da tela, que é quem fala com a galeria
  Future<void> enviarLogo(List<int> bytes, String nomeArquivo) async {
    _enviandoLogo = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _enviarLogo(
      LogoParams(bytes: bytes, nomeArquivo: nomeArquivo),
    );
    if (_disposed) return;

    result.fold((failure) => _errorMessage = failure.message, (url) {
      final config = _negocio.config;
      if (config != null) {
        _negocio.atualizarConfig(config.copyWith(logoUrl: url));
      }
    });

    _enviandoLogo = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
