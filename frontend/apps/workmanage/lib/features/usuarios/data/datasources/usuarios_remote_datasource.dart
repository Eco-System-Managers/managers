import 'package:dio/dio.dart';
import 'package:managers/core/network/paginacao.dart';
import 'package:managers/core/session/sessao_model.dart';

import '../../domain/params/equipe_params.dart';
import '../models/colaborador_model.dart';
import '../models/convite_model.dart';

// fala com /colaboradores/ e /convites/ da API e devolve models. não trata
// erro: se a requisição falhar, a DioException sobe para o repository
abstract class UsuariosRemoteDataSource {
  // o colaborador do usuário logado, com o papel. 404 sem_colaborador
  // enquanto o onboarding não foi concluído
  Future<ColaboradorModel> meuPerfil();

  // todos os colaboradores do negócio (a lista é paginada na API)
  Future<List<ColaboradorModel>> listar({String? busca});

  Future<ColaboradorModel> obter(int id);

  // cadastrar alguém sem login (só o proprietário)
  Future<ColaboradorModel> criar(DadosColaborador dados);

  Future<ColaboradorModel> atualizar(int id, DadosColaborador dados);

  // dar login a quem já está na equipe: cria o convite ligado ao registro
  Future<ConviteModel> convidar(int id, String email);

  Future<ColaboradorModel> ativar(int id);

  Future<void> desativar(int id);

  // o total de agendamentos futuros do colaborador
  Future<int> agendamentosPendentes(int id);

  Future<void> remover(int id);

  Future<List<ConviteModel>> listarConvites();

  Future<void> cancelarConvite(int id);

  // públicas: vão sem sessão
  Future<ConviteInfoModel> infoConvite(String token);

  Future<SessaoModel> aceitarConvite({
    required String token,
    required String senha,
  });
}

class UsuariosRemoteDataSourceImpl implements UsuariosRemoteDataSource {
  UsuariosRemoteDataSourceImpl(this.dio);

  final Dio dio;

  static const _colaboradores = 'colaboradores/';
  static const _convites = 'convites/';

  @override
  Future<ColaboradorModel> meuPerfil() async {
    final response = await dio.get<Map<String, dynamic>>(
      '${_colaboradores}me/',
    );
    return ColaboradorModel.fromJson(response.data!);
  }

  @override
  Future<List<ColaboradorModel>> listar({String? busca}) {
    return buscarTudo(
      dio,
      _colaboradores,
      query: {if (busca != null && busca.isNotEmpty) 'search': busca},
      item: ColaboradorModel.fromJson,
    );
  }

  @override
  Future<ColaboradorModel> obter(int id) async {
    final response = await dio.get<Map<String, dynamic>>('$_colaboradores$id/');
    return ColaboradorModel.fromJson(response.data!);
  }

  @override
  Future<ColaboradorModel> criar(DadosColaborador dados) async {
    final response = await dio.post<Map<String, dynamic>>(
      _colaboradores,
      data: ColaboradorModel.corpo(dados),
    );
    return ColaboradorModel.fromJson(response.data!);
  }

  @override
  Future<ColaboradorModel> atualizar(int id, DadosColaborador dados) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '$_colaboradores$id/',
      data: ColaboradorModel.corpo(dados),
    );
    return ColaboradorModel.fromJson(response.data!);
  }

  @override
  Future<ConviteModel> convidar(int id, String email) async {
    final response = await dio.post<Map<String, dynamic>>(
      '$_colaboradores$id/convidar/',
      data: {'email': email},
    );
    return ConviteModel.fromJson(response.data!);
  }

  @override
  Future<ColaboradorModel> ativar(int id) async {
    final response = await dio.post<Map<String, dynamic>>(
      '$_colaboradores$id/ativar/',
    );
    return ColaboradorModel.fromJson(response.data!);
  }

  @override
  Future<void> desativar(int id) async {
    await dio.post<void>('$_colaboradores$id/desativar/');
  }

  @override
  Future<int> agendamentosPendentes(int id) async {
    final response = await dio.get<Map<String, dynamic>>(
      '$_colaboradores$id/agendamentos-pendentes/',
    );
    return response.data!['total'] as int? ?? 0;
  }

  @override
  Future<void> remover(int id) async {
    await dio.delete<void>('$_colaboradores$id/remover/');
  }

  @override
  Future<List<ConviteModel>> listarConvites() {
    return buscarTudo(dio, _convites, item: ConviteModel.fromJson);
  }

  @override
  Future<void> cancelarConvite(int id) async {
    await dio.delete<void>('$_convites$id/');
  }

  @override
  Future<ConviteInfoModel> infoConvite(String token) async {
    final response = await dio.get<Map<String, dynamic>>(
      '${_convites}info/$token/',
    );
    return ConviteInfoModel.fromJson(response.data!);
  }

  // a resposta é o schema Sessao, com o refresh no corpo (mobile)
  @override
  Future<SessaoModel> aceitarConvite({
    required String token,
    required String senha,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '${_convites}aceitar/$token/',
      data: {'senha': senha},
    );
    return SessaoModel.fromJson(response.data!);
  }
}
