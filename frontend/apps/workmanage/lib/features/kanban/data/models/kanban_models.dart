import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/features/clientes/data/models/objeto_cliente_model.dart';
import 'package:managers/features/financeiro/data/models/cobranca_model.dart';

import '../../domain/entities/atendimento_kanban.dart';
import '../../domain/entities/etapa.dart';
import '../../domain/params/kanban_params.dart';

// os schemas EtapaKanban e AtendimentoKanban do contrato

class EtapaModel {
  const EtapaModel(this.json);

  final Map<String, dynamic> json;

  factory EtapaModel.fromJson(Map<String, dynamic> json) => EtapaModel(json);

  Etapa toEntity() {
    return Etapa(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      ordem: json['ordem'] as int? ?? 0,
      cor: json['cor'] as String? ?? '',
    );
  }

  // o corpo de criação e edição (EtapaKanbanRequest)
  static Map<String, dynamic> toJson(Etapa etapa) => {
    'nome': etapa.nome,
    'ordem': etapa.ordem,
    'cor': etapa.cor,
  };
}

class AtendimentoKanbanModel {
  const AtendimentoKanbanModel(this.json);

  final Map<String, dynamic> json;

  factory AtendimentoKanbanModel.fromJson(Map<String, dynamic> json) =>
      AtendimentoKanbanModel(json);

  AtendimentoKanban toEntity() {
    final data = json['data'] as String?;
    final hora = json['horario_entrada'] as String?;
    final criadoEm = json['criado_em'] as String?;
    return AtendimentoKanban(
      id: json['id'] as int,
      etapaId: json['etapa'] as int,
      etapaNome: json['etapa_nome'] as String? ?? '',
      objeto: objetoDoJson(json['objeto_detalhe'] as Map<String, dynamic>),
      clienteNome: json['cliente_nome'] as String? ?? '',
      clienteTelefone: json['cliente_telefone'] as String? ?? '',
      servicoId: json['servico'] as int,
      servicoNome: json['servico_nome'] as String? ?? '',
      servicoPreco: dinheiroDaApi(json['servico_preco'] as String? ?? '0'),
      servicoDuracao: json['servico_duracao'] as int? ?? 0,
      colaboradorId: json['colaborador'] as int?,
      colaboradorNome: json['colaborador_nome'] as String? ?? '',
      observacao: json['observacao'] as String? ?? '',
      data: data == null ? null : dataDaApi(data),
      horarioEntrada: hora == null ? null : horaDaApi(hora),
      pago: json['pago'] as bool? ?? false,
      faltou: json['faltou'] as bool? ?? false,
      desconto: dinheiroDaApi(json['desconto'] as String? ?? '0'),
      pagamentos: (json['pagamentos'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(pagamentoDoJson)
          .toList(),
      criadoEm: criadoEm == null ? null : dataHoraDaApi(criadoEm),
    );
  }

  // o corpo do POST (AtendimentoKanbanRequest)
  static Map<String, dynamic> corpoDeCriacao(NovoAtendimentoParams params) {
    return {
      'etapa': params.etapaId,
      'objeto': params.objetoId,
      'servico': params.servicoId,
      'data': dataParaApi(params.data),
      'horario_entrada': params.horarioEntrada == null
          ? null
          : horaParaApi(params.horarioEntrada!),
      'colaborador': ?params.colaboradorId,
      'observacao': params.observacao,
    };
  }
}
