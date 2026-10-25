import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';

import '../../domain/entities/agendamento.dart';
import '../../domain/params/agenda_params.dart';

// o schema Agendamento do contrato. serviços e pagamentos vêm aninhados e
// só de leitura; o cliente e o colaborador vêm como ids, com os nomes ao lado
class AgendamentoModel {
  const AgendamentoModel(this.json);

  final Map<String, dynamic> json;

  factory AgendamentoModel.fromJson(Map<String, dynamic> json) =>
      AgendamentoModel(json);

  Agendamento toEntity() {
    final servicos = (json['servicos'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (s) => ServicoAgendado(
            id: s['id'] as int,
            servicoId: s['servico'] as int,
            nome: s['servico_nome'] as String? ?? '',
            duracao: s['servico_duracao'] as int? ?? 0,
            precoCobrado: dinheiroDaApi(s['preco_cobrado'] as String? ?? '0'),
            desconto: dinheiroDaApi(s['desconto'] as String? ?? '0'),
          ),
        )
        .toList();
    final pagamentos = (json['pagamentos'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (p) => Pagamento(
            forma:
                FormaPagamentoNomes.daApi(p['forma'] as String? ?? '') ??
                FormaPagamento.dinheiro,
            valor: dinheiroDaApi(p['valor'] as String? ?? '0'),
          ),
        )
        .toList();
    final criadoEm = json['criado_em'] as String?;

    return Agendamento(
      id: json['id'] as int,
      clienteId: json['cliente'] as int,
      clienteNome: json['cliente_nome'] as String? ?? '',
      clienteTelefone: json['cliente_telefone'] as String? ?? '',
      colaboradorId: json['colaborador'] as int?,
      colaboradorNome: json['colaborador_nome'] as String?,
      dataHora: dataHoraDaApi(json['data_hora'] as String),
      status:
          StatusAgendamento.values.asNameMap()[json['status'] as String? ??
              ''] ??
          StatusAgendamento.agendado,
      desconto: dinheiroDaApi(json['desconto'] as String? ?? '0'),
      observacoes: json['observacoes'] as String? ?? '',
      servicos: servicos,
      pagamentos: pagamentos,
      criadoEm: criadoEm == null ? null : dataHoraDaApi(criadoEm),
    );
  }

  // o corpo do POST (AgendamentoRequest): um serviço, pelo servico_id
  static Map<String, dynamic> corpoDeCriacao(NovoAgendamentoParams params) {
    return {
      'cliente': params.clienteId,
      'servico_id': params.servicoId,
      'colaborador': params.colaboradorId,
      'data_hora': dataHoraParaApi(params.dataHora),
      'observacoes': params.observacoes,
    };
  }

  // o corpo do POST cobrar (CobrancaRequest)
  static Map<String, dynamic> corpoDeCobranca(CobrancaParams params) {
    return {
      'desconto': dinheiroParaApi(params.desconto),
      'pagamentos': [
        for (final p in params.pagamentos)
          {'forma': p.forma.slug, 'valor': dinheiroParaApi(p.valor)},
      ],
      'credito_aplicado': dinheiroParaApi(params.creditoAplicado),
      'troco_credito': dinheiroParaApi(params.trocoCredito),
    };
  }
}
