import 'package:dio/dio.dart';
import 'package:managers/core/network/paginacao.dart';

import '../../domain/entities/objeto_cliente.dart';
import '../models/cliente_model.dart';
import '../models/objeto_cliente_model.dart';

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

  // os objetos do cliente têm rotas próprias (veiculos/, pets/)
  Future<VeiculoModel> criarVeiculo(Veiculo veiculo);

  Future<VeiculoModel> atualizarVeiculo(Veiculo veiculo);

  Future<void> removerVeiculo(int id);

  Future<PetModel> criarPet(Pet pet);

  Future<PetModel> atualizarPet(Pet pet);

  Future<void> removerPet(int id);
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

  @override
  Future<VeiculoModel> criarVeiculo(Veiculo veiculo) async {
    final response = await dio.post<Map<String, dynamic>>(
      'veiculos/',
      data: VeiculoModel.toJson(veiculo),
    );
    return VeiculoModel.fromJson(response.data!);
  }

  @override
  Future<VeiculoModel> atualizarVeiculo(Veiculo veiculo) async {
    final response = await dio.patch<Map<String, dynamic>>(
      'veiculos/${veiculo.id}/',
      data: VeiculoModel.toJson(veiculo),
    );
    return VeiculoModel.fromJson(response.data!);
  }

  @override
  Future<void> removerVeiculo(int id) async {
    await dio.delete<void>('veiculos/$id/');
  }

  @override
  Future<PetModel> criarPet(Pet pet) async {
    final response = await dio.post<Map<String, dynamic>>(
      'pets/',
      data: PetModel.toJson(pet),
    );
    return PetModel.fromJson(response.data!);
  }

  @override
  Future<PetModel> atualizarPet(Pet pet) async {
    final response = await dio.patch<Map<String, dynamic>>(
      'pets/${pet.id}/',
      data: PetModel.toJson(pet),
    );
    return PetModel.fromJson(response.data!);
  }

  @override
  Future<void> removerPet(int id) async {
    await dio.delete<void>('pets/$id/');
  }
}
