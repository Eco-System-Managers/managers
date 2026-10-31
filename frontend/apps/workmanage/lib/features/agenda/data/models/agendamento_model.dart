import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/features/financeiro/data/models/cobranca_model.dart';

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
        .map(pagamentoDoJson)
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
      acrescimo: dinheiroDaApi(json['acrescimo'] as String? ?? '0'),
      acrescimoMotivo: json['acrescimo_motivo'] as String? ?? '',
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
}
