import 'package:dio/dio.dart';

import '../models/empresa_config_model.dart';
import '../models/endereco_model.dart';
import '../models/horario_funcionamento_model.dart';
import 'onboarding_remote_datasource.dart';

// simulação da API, guardando tudo em memória. imita as regras do backend
// que a tela precisa sentir (tipo de agenda pelo nicho, documento para
// concluir) e falha do mesmo jeito que o Dio: com DioException e o corpo
// {detail, code}, para o repository tratar igual ao de verdade
class OnboardingFakeDataSource implements OnboardingRemoteDataSource {
  // a config já começa com o nome que a pessoa deu no cadastro
  Map<String, dynamic> _config = {'nome': 'Minha empresa'};

  List<Map<String, dynamic>> _horarios = [
    for (var dia = 0; dia < 7; dia++)
      {
        'dia': dia,
        'ativo': dia < 6, // domingo fechado
        'abertura': dia < 6 ? '08:00:00' : null,
        'fechamento': dia < 6 ? '18:00:00' : null,
        'capacidade': null,
      },
  ];

  // espelha NICHO_TIPO, em backend/apps_work/empresa/serializers.py
  static const _nichosKanban = {'lava_rapido', 'banho_tosa'};

  @override
  Future<EmpresaConfigModel> buscarConfig() async {
    await _simularRede();
    return EmpresaConfigModel.fromJson(_config);
  }

  @override
  Future<EmpresaConfigModel> salvarConfig(EmpresaConfigModel config) async {
    await _simularRede();
    final nicho = config.nicho;
    _config = {
      ..._config,
      ...config.toJson(),
      'tipo_agenda': _nichosKanban.contains(nicho) ? 'kanban' : 'horario',
    };
    return EmpresaConfigModel.fromJson(_config);
  }

  @override
  Future<EnderecoModel> buscarEnderecoPorCep(String cep) async {
    await _simularRede();
    // "00000000" simula CEP inexistente, para testar a mensagem de erro
    if (cep.length != 8 || cep == '00000000') {
      throw _erro('cep/', 404, 'CEP não encontrado.', 'cep_nao_encontrado');
    }
    return EnderecoModel.fromJson({
      'cep': cep,
      'endereco': 'Rua Exemplo',
      'cidade': 'São Paulo',
      'uf': 'SP',
    });
  }

  @override
  Future<List<HorarioFuncionamentoModel>> buscarHorarios() async {
    await _simularRede();
    return _horarios.map(HorarioFuncionamentoModel.fromJson).toList();
  }

  @override
  Future<List<HorarioFuncionamentoModel>> salvarHorarios(
    List<HorarioFuncionamentoModel> horarios,
  ) async {
    await _simularRede();
    _horarios = horarios.map((h) => h.toJson()).toList();
    return _horarios.map(HorarioFuncionamentoModel.fromJson).toList();
  }

  @override
  Future<EmpresaConfigModel> concluir() async {
    await _simularRede();
    // mesma regra do EmpresaConfigSerializer.validate
    if ((_config['documento'] as String? ?? '').isEmpty) {
      throw _erro(
        'empresa/config/',
        400,
        'Informe o CPF ou o CNPJ do negócio.',
        'documento_obrigatorio',
      );
    }
    _config = {..._config, 'onboarding_concluido': true};
    return EmpresaConfigModel.fromJson(_config);
  }

  Future<void> _simularRede() {
    return Future.delayed(const Duration(milliseconds: 600));
  }

  DioException _erro(String path, int status, String detail, String code) {
    final request = RequestOptions(path: path);
    return DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: status,
        data: {'detail': detail, 'code': code},
      ),
      type: DioExceptionType.badResponse,
    );
  }
}
