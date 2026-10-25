import 'package:dio/dio.dart';
import 'package:managers/core/network/paginacao.dart';

import '../models/cliente_model.dart';

// fala com /clientes/ da API e devolve models. não trata erro: se a
// requisição falhar, a DioException sobe para o repository
abstract class ClientesRemoteDataSource {
  // uma página por vez: a lista de clientes cresce, e a tela pede a
  // próxima quando chega ao fim
  Future<Pagina<ClienteModel>> listar({int pagina = 1, String? busca});

  Future<ClienteModel> obter(int id);

  Future<ClienteModel> criar(ClienteModel cliente);

  Future<ClienteModel> atualizar(int id, ClienteModel cliente);

  // cliente manual é apagado; o que veio do app é arquivado e desvinculado.
  // com atendimento registrado a API recusa (400 cliente_com_atendimentos)
  Future<void> remover(int id);
}

class ClientesRemoteDataSourceImpl implements ClientesRemoteDataSource {
  ClientesRemoteDataSourceImpl(this.dio);

  final Dio dio;

  static const _clientes = 'clientes/';

  @override
  Future<Pagina<ClienteModel>> listar({int pagina = 1, String? busca}) async {
    final response = await dio.get<Map<String, dynamic>>(
      _clientes,
      queryParameters: {
        'page': pagina,
        if (busca != null && busca.isNotEmpty) 'search': busca,
      },
    );
    return Pagina.fromJson(response.data!, ClienteModel.fromJson);
  }

  @override
  Future<ClienteModel> obter(int id) async {
    final response = await dio.get<Map<String, dynamic>>('$_clientes$id/');
    return ClienteModel.fromJson(response.data!);
  }

  @override
  Future<ClienteModel> criar(ClienteModel cliente) async {
    final response = await dio.post<Map<String, dynamic>>(
      _clientes,
      data: cliente.toJson(),
    );
    return ClienteModel.fromJson(response.data!);
  }

  // PATCH com o formulário inteiro: é como a API trata os campos
  // espelhados do cliente que veio do app (ignora, em vez de recusar)
  @override
  Future<ClienteModel> atualizar(int id, ClienteModel cliente) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '$_clientes$id/',
      data: cliente.toJson(),
    );
    return ClienteModel.fromJson(response.data!);
  }

  @override
  Future<void> remover(int id) async {
    await dio.delete('$_clientes$id/');
  }
}
