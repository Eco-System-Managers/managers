import 'package:dio/dio.dart';
import 'package:managers/core/network/paginacao.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';

import '../../domain/entities/assinatura.dart';

// fala com /billing/ da API e já devolve as entidades: as respostas são
// leitura pura. não trata erro: a DioException sobe para o repository
abstract class AssinaturaRemoteDataSource {
  // 404 quando o negócio ainda não tem assinatura
  Future<Assinatura> obter();

  // o link do checkout do plano padrão, para abrir no navegador
  Future<String> iniciar();

  // vincula ao negócio a assinatura feita no checkout (id do gateway)
  Future<Assinatura> confirmar(String idExterno);

  Future<Assinatura> cancelar();

  Future<List<PagamentoAssinatura>> listarPagamentos();
}

class AssinaturaRemoteDataSourceImpl implements AssinaturaRemoteDataSource {
  AssinaturaRemoteDataSourceImpl(this.dio);

  final Dio dio;

  @override
  Future<Assinatura> obter() async {
    final response = await dio.get<Map<String, dynamic>>('billing/assinatura/');
    return _assinatura(response.data!);
  }

  @override
  Future<String> iniciar() async {
    final response = await dio.post<Map<String, dynamic>>(
      'billing/assinatura/iniciar/',
    );
    return response.data!['link_checkout'] as String;
  }

  @override
  Future<Assinatura> confirmar(String idExterno) async {
    final response = await dio.post<Map<String, dynamic>>(
      'billing/assinatura/confirmar/',
      data: {'id_externo': idExterno},
    );
    return _assinatura(response.data!);
  }

  @override
  Future<Assinatura> cancelar() async {
    final response = await dio.post<Map<String, dynamic>>(
      'billing/assinatura/cancelar/',
    );
    return _assinatura(response.data!);
  }

  @override
  Future<List<PagamentoAssinatura>> listarPagamentos() {
    return buscarTudo(
      dio,
      'billing/pagamentos/',
      item: (json) => PagamentoAssinatura(
        valor: dinheiroDaApi(json['valor'] as String? ?? '0'),
        status:
            StatusPagamentoAssinatura.values.asNameMap()[json['status']
                as String?] ??
            StatusPagamentoAssinatura.pendente,
        data: dataDaApi(json['data'] as String),
      ),
    );
  }

  Assinatura _assinatura(Map<String, dynamic> json) {
    final trialFim = json['trial_fim'] as String?;
    return Assinatura(
      status:
          StatusAssinatura.values.asNameMap()[json['status'] as String?] ??
          StatusAssinatura.trial,
      planoNome: json['plano_nome'] as String? ?? '',
      inicio: dataDaApi(json['inicio'] as String),
      proximoVencimento: dataDaApi(json['proximo_vencimento'] as String),
      trialFim: trialFim == null ? null : dataDaApi(trialFim),
      bloqueada: json['bloqueada'] as bool? ?? false,
      checkoutAberto: json['checkout_aberto'] as bool? ?? false,
    );
  }
}
