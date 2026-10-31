import 'package:managers/core/utils/dinheiro.dart';

import '../../domain/entities/pagamento.dart';
import '../../domain/params/cobranca_params.dart';

// o schema CobrancaRequest do contrato, igual para agendamentos/{id}/cobrar/
// e kanban/atendimentos/{id}/cobrar/. servico_ids só vai quando há troca:
// sem o campo a API cobra o serviço combinado
Map<String, dynamic> corpoDeCobranca(CobrancaParams params) {
  return {
    'desconto': dinheiroParaApi(params.desconto),
    'acrescimo': dinheiroParaApi(params.acrescimo),
    'acrescimo_motivo': params.acrescimoMotivo,
    if (params.servicoIds != null) 'servico_ids': params.servicoIds,
    'pagamentos': [
      for (final p in params.pagamentos)
        {'forma': p.forma.slug, 'valor': dinheiroParaApi(p.valor)},
    ],
    'credito_aplicado': dinheiroParaApi(params.creditoAplicado),
    'troco_credito': dinheiroParaApi(params.trocoCredito),
  };
}

// um item de pagamentos[] (PagamentoAgendamento / PagamentoAtendimento)
Pagamento pagamentoDoJson(Map<String, dynamic> json) {
  return Pagamento(
    forma:
        FormaPagamentoNomes.daApi(json['forma'] as String? ?? '') ??
        FormaPagamento.dinheiro,
    valor: dinheiroDaApi(json['valor'] as String? ?? '0'),
  );
}
