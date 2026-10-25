import 'package:dio/dio.dart';

import '../models/empresa_config_model.dart';
import '../models/endereco_model.dart';
import '../models/horario_funcionamento_model.dart';
import 'onboarding_remote_datasource.dart';

// simulação da API, guardando tudo em memória. imita as regras do backend
// que a tela precisa sentir (modo de agenda pelo nicho, documento para
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

  // espelha os mapas do ModoAgendaService, em
  // backend/apps_work/empresa/services.py. nicho fora daqui é horário
  static const _modoPorNicho = {
    'lava_rapido': ('kanban', 'veiculo'),
    'banho_tosa': ('kanban', 'pet'),
  };

  @override
  Future<EmpresaConfigModel> buscarConfig() async {
    await _simularRede();
    return EmpresaConfigModel.fromJson(_config);
  }

  @override
  Future<EmpresaConfigModel> salvarConfig(EmpresaConfigModel config) async {
    await _simularRede();
    final json = config.toJson();
    _config = {..._config, ...json, ..._resolverModo(json)};
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

  // mesma regra do ModoAgendaService.resolver (sem a trava pós-onboarding,
  // que o wizard não alcança)
  Map<String, String> _resolverModo(Map<String, dynamic> json) {
    if (json['nicho'] != 'outro') {
      final (tipoAgenda, tipoObjeto) =
          _modoPorNicho[json['nicho']] ?? ('horario', '');
      return {
        'nicho_descricao': '',
        'tipo_agenda': tipoAgenda,
        'tipo_objeto': tipoObjeto,
      };
    }

    final descricao = (json['nicho_descricao'] as String).trim();
    if (descricao.isEmpty) {
      throw _erro(
        'empresa/config/',
        400,
        'Descreva o ramo do seu negócio.',
        'nicho_descricao_obrigatoria',
      );
    }
    final tipoAgenda = json['tipo_agenda'] as String;
    final tipoObjeto = json['tipo_objeto'] as String;
    if (tipoAgenda == 'kanban' && tipoObjeto.isEmpty) {
      throw _erro(
        'empresa/config/',
        400,
        'Informe se o negócio recebe veículos ou pets.',
        'tipo_objeto_obrigatorio',
      );
    }
    return {
      'nicho_descricao': descricao,
      'tipo_agenda': tipoAgenda,
      'tipo_objeto': tipoAgenda == 'kanban' ? tipoObjeto : '',
    };
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
