import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/cep/cep_provider.dart';
import 'package:managers/core/network/dio_client.dart';
import 'package:managers/core/session/sessao_provider.dart';
import 'package:managers/features/servicos/servicos_provider.dart';
import 'package:managers/features/usuarios/usuarios_provider.dart';

import 'data/datasources/empresa_remote_datasource.dart';
import 'data/repositories/empresa_repository_impl.dart';
import 'domain/repositories/empresa_repository.dart';
import 'domain/usecases/buscar_config_use_case.dart';
import 'domain/usecases/buscar_endereco_por_cep_use_case.dart';
import 'domain/usecases/buscar_horarios_use_case.dart';
import 'domain/usecases/concluir_onboarding_use_case.dart';
import 'domain/usecases/enviar_logo_use_case.dart';
import 'domain/usecases/salvar_config_use_case.dart';
import 'domain/usecases/salvar_horarios_use_case.dart';
import 'presentation/providers/configuracoes_provider.dart';
import 'presentation/providers/dados_negocio_provider.dart';
import 'presentation/providers/horarios_provider.dart';
import 'presentation/providers/nichos_provider.dart';
import 'presentation/providers/negocio_atual_provider.dart';

// injeção de dependências da empresa: é o único lugar que conhece as
// implementações. o onboarding e a splash também usam os use cases daqui
final empresaRemoteDataSourceProvider = Provider<EmpresaRemoteDataSource>(
  (ref) => EmpresaRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final empresaRepositoryProvider = Provider<EmpresaRepository>(
  (ref) => EmpresaRepositoryImpl(
    ref.watch(empresaRemoteDataSourceProvider),
    ref.watch(cepDataSourceProvider),
  ),
);

final buscarConfigUseCaseProvider = Provider(
  (ref) => BuscarConfigUseCase(ref.watch(empresaRepositoryProvider)),
);

final salvarConfigUseCaseProvider = Provider(
  (ref) => SalvarConfigUseCase(ref.watch(empresaRepositoryProvider)),
);

final buscarEnderecoPorCepUseCaseProvider = Provider(
  (ref) => BuscarEnderecoPorCepUseCase(ref.watch(empresaRepositoryProvider)),
);

final buscarHorariosUseCaseProvider = Provider(
  (ref) => BuscarHorariosUseCase(ref.watch(empresaRepositoryProvider)),
);

final salvarHorariosUseCaseProvider = Provider(
  (ref) => SalvarHorariosUseCase(ref.watch(empresaRepositoryProvider)),
);

final concluirOnboardingUseCaseProvider = Provider(
  (ref) => ConcluirOnboardingUseCase(ref.watch(empresaRepositoryProvider)),
);

final enviarLogoUseCaseProvider = Provider(
  (ref) => EnviarLogoUseCase(ref.watch(empresaRepositoryProvider)),
);

// o negócio atual vive enquanto o app estiver aberto (sem autoDispose) e
// zera sozinho quando a sessão acaba, para a próxima pessoa que entrar não
// ver a config de outro negócio
final negocioAtualProvider = Provider<NegocioAtualProvider>((ref) {
  final sessao = ref.watch(sessaoControllerProvider);
  final negocio = NegocioAtualProvider(
    buscarConfig: ref.watch(buscarConfigUseCaseProvider),
    buscarMeuPerfil: ref.watch(buscarMeuPerfilUseCaseProvider),
  );
  void aoMudarSessao() {
    if (!sessao.autenticado) negocio.limpar();
  }

  sessao.addListener(aoMudarSessao);
  ref.onDispose(() {
    sessao.removeListener(aoMudarSessao);
    negocio.dispose();
  });
  return negocio;
});

// estado das telas de configurações. autoDispose: cada tela abre, edita e
// some; o que ficou salvo está no negócio atual
final configuracoesProvider = Provider.autoDispose<ConfiguracoesProvider>((
  ref,
) {
  final provider = ConfiguracoesProvider(
    negocio: ref.watch(negocioAtualProvider),
    enviarLogo: ref.watch(enviarLogoUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

final dadosNegocioProvider = Provider.autoDispose<DadosNegocioProvider>((ref) {
  final provider = DadosNegocioProvider(
    negocio: ref.watch(negocioAtualProvider),
    salvarConfig: ref.watch(salvarConfigUseCaseProvider),
    buscarEnderecoPorCep: ref.watch(buscarEnderecoPorCepUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

// conta os serviços dos nichos que saem com o use case do catálogo
final nichosProvider = Provider.autoDispose<NichosProvider>((ref) {
  final provider = NichosProvider(
    negocio: ref.watch(negocioAtualProvider),
    salvarConfig: ref.watch(salvarConfigUseCaseProvider),
    listarServicos: ref.watch(listarServicosUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

final horariosProvider = Provider.autoDispose<HorariosProvider>((ref) {
  final provider = HorariosProvider(
    negocio: ref.watch(negocioAtualProvider),
    buscarHorarios: ref.watch(buscarHorariosUseCaseProvider),
    salvarHorarios: ref.watch(salvarHorariosUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});
