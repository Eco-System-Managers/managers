import 'package:dio/dio.dart';
import 'package:managers/core/network/paginacao.dart';

import '../models/servico_model.dart';

// fala com /servicos/ da API e devolve models. não trata erro: se a
// requisição falhar, a DioException sobe para o repository
abstract class ServicosRemoteDataSource {
  // a lista é paginada na API; aqui vem inteira (o catálogo é pequeno)
  Future<List<ServicoModel>> listar({String? busca, bool? ativo});

  Future<ServicoModel> obter(int id);

  Future<ServicoModel> criar(ServicoModel servico);

  Future<ServicoModel> atualizar(int id, ServicoModel servico);

  // inativar e reativar são um PATCH só no ativo. o DELETE da API apaga de
  // verdade (e estoura se o serviço já foi agendado), por isso não é usado
  Future<ServicoModel> alterarAtivo(int id, bool ativo);
}

class ServicosRemoteDataSourceImpl implements ServicosRemoteDataSource {
  ServicosRemoteDataSourceImpl(this.dio);

  final Dio dio;

  static const _servicos = 'servicos/';

  @override
  Future<List<ServicoModel>> listar({String? busca, bool? ativo}) {
    return buscarTudo(
      dio,
      _servicos,
      query: {
        if (busca != null && busca.isNotEmpty) 'search': busca,
        if (ativo != null) 'ativo': ativo.toString(),
      },
      item: ServicoModel.fromJson,
    );
  }

  @override
  Future<ServicoModel> obter(int id) async {
    final response = await dio.get<Map<String, dynamic>>('$_servicos$id/');
    return ServicoModel.fromJson(response.data!);
  }

  @override
  Future<ServicoModel> criar(ServicoModel servico) async {
    final response = await dio.post<Map<String, dynamic>>(
      _servicos,
      data: servico.toJson(),
    );
    return ServicoModel.fromJson(response.data!);
  }

  @override
  Future<ServicoModel> atualizar(int id, ServicoModel servico) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '$_servicos$id/',
      data: servico.toJson(),
    );
    return ServicoModel.fromJson(response.data!);
  }

  @override
  Future<ServicoModel> alterarAtivo(int id, bool ativo) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '$_servicos$id/',
      data: {'ativo': ativo},
    );
    return ServicoModel.fromJson(response.data!);
  }
}
