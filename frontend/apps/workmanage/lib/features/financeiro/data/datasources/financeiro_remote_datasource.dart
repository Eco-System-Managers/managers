import 'package:dio/dio.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';

import '../../domain/entities/caixa.dart';
import '../../domain/entities/saldo_cliente.dart';

// fala com /financeiro/ da API e já devolve as entidades: as respostas são
// leitura pura, sem ida e volta, então não há model separado
abstract class FinanceiroRemoteDataSource {
  // sem datas, a API usa hoje nas duas
  Future<Caixa> caixa({DateTime? inicio, DateTime? fim, int? colaboradorId});

  Future<SaldoCliente> saldoDoCliente(int clienteId);
}

class FinanceiroRemoteDataSourceImpl implements FinanceiroRemoteDataSource {
  FinanceiroRemoteDataSourceImpl(this.dio);

  final Dio dio;

  @override
  Future<Caixa> caixa({
    DateTime? inicio,
    DateTime? fim,
    int? colaboradorId,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      'financeiro/caixa/',
      queryParameters: {
        if (inicio != null) 'data_inicio': dataParaApi(inicio),
        if (fim != null) 'data_fim': dataParaApi(fim),
        'colaborador': ?colaboradorId,
      },
    );
    final json = response.data!;
    final kpis = json['kpis'] as Map<String, dynamic>;
    return Caixa(
      total: dinheiroDaApi(kpis['total'] as String? ?? '0'),
      ticketMedio: dinheiroDaApi(kpis['ticket_medio'] as String? ?? '0'),
      atendimentos: kpis['atendimentos'] as int? ?? 0,
      repasse: dinheiroDaApi(kpis['repasse'] as String? ?? '0'),
      casa: kpis['casa'] == null ? null : dinheiroDaApi(kpis['casa'] as String),
      porForma: [
        for (final f
            in (json['por_forma'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          CaixaPorForma(
            forma: f['forma'] as String? ?? '',
            total: dinheiroDaApi(f['total'] as String? ?? '0'),
            percentual: f['percentual'] as int? ?? 0,
          ),
      ],
      pagamentos: [
        for (final p
            in (json['pagamentos'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          CaixaPagamento(
            origemAgenda: (p['origem'] as String? ?? 'agenda') == 'agenda',
            clienteNome: p['cliente_nome'] as String? ?? '',
            servicoNome: p['servico_nome'] as String? ?? '',
            colaboradorNome: p['colaborador_nome'] as String? ?? '',
            forma: p['forma'] as String? ?? '',
            valor: dinheiroDaApi(p['valor'] as String? ?? '0'),
            dataHora: dataHoraDaApi(p['data_hora'] as String),
          ),
      ],
    );
  }

  @override
  Future<SaldoCliente> saldoDoCliente(int clienteId) async {
    final response = await dio.get<Map<String, dynamic>>(
      'financeiro/clientes/$clienteId/saldo/',
    );
    final json = response.data!;
    return SaldoCliente(
      saldo: dinheiroDaApi(json['saldo'] as String? ?? '0'),
      transacoes: [
        for (final t
            in (json['transacoes'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          TransacaoCredito(
            id: t['id'] as int,
            credito: (t['tipo'] as String? ?? 'credito') == 'credito',
            valor: dinheiroDaApi(t['valor'] as String? ?? '0'),
            origem: t['origem'] as String? ?? '',
            descricao: t['descricao'] as String? ?? '',
            criadoEm: dataHoraDaApi(t['criado_em'] as String),
          ),
      ],
    );
  }
}
