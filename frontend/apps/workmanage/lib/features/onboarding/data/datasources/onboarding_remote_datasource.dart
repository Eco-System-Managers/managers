import '../models/empresa_config_model.dart';
import '../models/endereco_model.dart';
import '../models/horario_funcionamento_model.dart';

// fala com a API e devolve models. não trata erro: se a requisição falhar,
// a DioException sobe para o repository, que decide a mensagem.
// por enquanto só existe a versão simulada (onboarding_fake_datasource.dart);
// a com Dio entra quando o app tiver o token da sessão
abstract class OnboardingRemoteDataSource {
  Future<EmpresaConfigModel> buscarConfig();

  Future<EmpresaConfigModel> salvarConfig(EmpresaConfigModel config);

  Future<EnderecoModel> buscarEnderecoPorCep(String cep);

  Future<List<HorarioFuncionamentoModel>> buscarHorarios();

  Future<List<HorarioFuncionamentoModel>> salvarHorarios(
    List<HorarioFuncionamentoModel> horarios,
  );

  Future<EmpresaConfigModel> concluir();
}
