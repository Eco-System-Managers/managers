import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/empresa/domain/entities/empresa_config.dart';
import 'package:managers/features/empresa/domain/params/logo_params.dart';
import 'package:managers/features/empresa/domain/usecases/buscar_config_use_case.dart';
import 'package:managers/features/empresa/domain/usecases/enviar_logo_use_case.dart';
import 'package:managers/features/empresa/presentation/providers/configuracoes_provider.dart';
import 'package:managers/features/empresa/presentation/providers/negocio_atual_provider.dart';
import 'package:managers/features/usuarios/domain/usecases/buscar_meu_perfil_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockEnviarLogo extends Mock implements EnviarLogoUseCase {}

class _MockBuscarConfig extends Mock implements BuscarConfigUseCase {}

class _MockBuscarMeuPerfil extends Mock implements BuscarMeuPerfilUseCase {}

void main() {
  late _MockEnviarLogo enviarLogo;
  late NegocioAtualProvider negocio;
  late ConfiguracoesProvider provider;

  setUpAll(() {
    registerFallbackValue(const LogoParams(bytes: [], nomeArquivo: ''));
  });

  setUp(() {
    enviarLogo = _MockEnviarLogo();
    negocio = NegocioAtualProvider(
      buscarConfig: _MockBuscarConfig(),
      buscarMeuPerfil: _MockBuscarMeuPerfil(),
    )..atualizarConfig(const EmpresaConfig(nome: 'Barbearia Demo'));
    provider = ConfiguracoesProvider(negocio: negocio, enviarLogo: enviarLogo);
  });

  test('logo enviada atualiza a URL no negócio atual', () async {
    when(() => enviarLogo(any()))
        .thenAnswer((_) async => const Right('https://s3/logo.webp'));

    await provider.enviarLogo([1, 2, 3], 'logo.png');

    final params =
        verify(() => enviarLogo(captureAny())).captured.single as LogoParams;
    expect(params.nomeArquivo, 'logo.png');
    expect(params.bytes, [1, 2, 3]);
    expect(negocio.logoUrl, 'https://s3/logo.webp');
    expect(provider.enviandoLogo, isFalse);
    expect(provider.errorMessage, isNull);
  });

  test('armazenamento indisponível mostra o detail da API', () async {
    when(() => enviarLogo(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'Não foi possível enviar a imagem. Tente novamente.',
          code: 'armazenamento_indisponivel',
        ),
      ),
    );

    await provider.enviarLogo([1], 'logo.png');

    expect(
      provider.errorMessage,
      'Não foi possível enviar a imagem. Tente novamente.',
    );
    expect(negocio.logoUrl, '');
  });
}
