import 'package:dio/dio.dart';
import 'package:managers/core/network/paginacao.dart';

import '../models/colaborador_model.dart';

// fala com /colaboradores/ da API e devolve models. não trata erro: se a
// requisição falhar, a DioException sobe para o repository
abstract class UsuariosRemoteDataSource {
  // o colaborador do usuário logado, com o papel. 404 sem_colaborador
  // enquanto o onboarding não foi concluído
  Future<ColaboradorModel> meuPerfil();

  // todos os colaboradores do negócio (a lista é paginada na API)
  Future<List<ColaboradorModel>> listar({String? busca});
}

class UsuariosRemoteDataSourceImpl implements UsuariosRemoteDataSource {
  UsuariosRemoteDataSourceImpl(this.dio);

  final Dio dio;

  @override
  Future<ColaboradorModel> meuPerfil() async {
    final response = await dio.get<Map<String, dynamic>>('colaboradores/me/');
    return ColaboradorModel.fromJson(response.data!);
  }

  @override
  Future<List<ColaboradorModel>> listar({String? busca}) {
    return buscarTudo(
      dio,
      'colaboradores/',
      query: {if (busca != null && busca.isNotEmpty) 'search': busca},
      item: ColaboradorModel.fromJson,
    );
  }
}
