import 'package:dio/dio.dart';

import '../models/empresa_config_model.dart';
import '../models/horario_funcionamento_model.dart';

// fala com /empresa/ da API e devolve models. não trata erro: se a
// requisição falhar, a DioException sobe para o repository, que decide
abstract class EmpresaRemoteDataSource {
  Future<EmpresaConfigModel> buscarConfig();

  Future<EmpresaConfigModel> salvarConfig(EmpresaConfigModel config);

  Future<List<HorarioFuncionamentoModel>> buscarHorarios();

  Future<List<HorarioFuncionamentoModel>> salvarHorarios(
    List<HorarioFuncionamentoModel> horarios,
  );

  Future<EmpresaConfigModel> concluir();

  // devolve a URL pública da logo nova
  Future<String> enviarLogo(List<int> bytes, String nomeArquivo);
}

class EmpresaRemoteDataSourceImpl implements EmpresaRemoteDataSource {
  EmpresaRemoteDataSourceImpl(this.dio);

  final Dio dio;

  static const _config = 'empresa/config/';
  static const _horarios = 'empresa/horarios/';
  static const _logo = 'empresa/config/logo/';

  // a config nasce no primeiro GET, já com o nome dado no cadastro
  @override
  Future<EmpresaConfigModel> buscarConfig() async {
    final response = await dio.get<Map<String, dynamic>>(_config);
    return EmpresaConfigModel.fromJson(response.data!);
  }

  // PATCH: manda o que tem; o backend devolve a config inteira, já com o
  // tipo de agenda que o nicho definiu
  @override
  Future<EmpresaConfigModel> salvarConfig(EmpresaConfigModel config) async {
    final response = await dio.patch<Map<String, dynamic>>(
      _config,
      data: config.toJson(),
    );
    return EmpresaConfigModel.fromJson(response.data!);
  }

  // os dias vêm como array, sem paginação; só os que já foram salvos
  @override
  Future<List<HorarioFuncionamentoModel>> buscarHorarios() async {
    final response = await dio.get<List<dynamic>>(_horarios);
    return [
      for (final h in response.data!)
        HorarioFuncionamentoModel.fromJson(h as Map<String, dynamic>),
    ];
  }

  // não existe PUT na coleção: o POST faz upsert por dia (201 cria, 200
  // atualiza). um por dia, em paralelo
  @override
  Future<List<HorarioFuncionamentoModel>> salvarHorarios(
    List<HorarioFuncionamentoModel> horarios,
  ) async {
    final respostas = await Future.wait([
      for (final h in horarios)
        dio.post<Map<String, dynamic>>(_horarios, data: h.toJson()),
    ]);
    final salvos = [
      for (final r in respostas) HorarioFuncionamentoModel.fromJson(r.data!),
    ];
    salvos.sort((a, b) => a.dia.compareTo(b.dia));
    return salvos;
  }

  // concluir é a mesma rota da config: o backend exige o documento e, ao
  // concluir, cria o colaborador do dono (e as etapas do kanban)
  @override
  Future<EmpresaConfigModel> concluir() async {
    final response = await dio.patch<Map<String, dynamic>>(
      _config,
      data: {'onboarding_concluido': true},
    );
    return EmpresaConfigModel.fromJson(response.data!);
  }

  // multipart com o campo `logo` (UploadLogoRequest). a API valida, converte
  // para webp e grava no S3; sem bucket no ambiente, responde 503
  // armazenamento_indisponivel, que vira ServerFailure com o detail
  @override
  Future<String> enviarLogo(List<int> bytes, String nomeArquivo) async {
    final form = FormData.fromMap({
      'logo': MultipartFile.fromBytes(bytes, filename: nomeArquivo),
    });
    final response = await dio.post<Map<String, dynamic>>(_logo, data: form);
    return response.data!['logo_url'] as String;
  }
}
