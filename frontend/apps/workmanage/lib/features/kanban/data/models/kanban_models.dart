import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/features/clientes/data/models/objeto_cliente_model.dart';
import 'package:managers/features/financeiro/data/models/cobranca_model.dart';

import '../../domain/entities/atendimento_kanban.dart';
import '../../domain/entities/capacidade_do_dia.dart';
import '../../domain/entities/etapa.dart';
import '../../domain/params/kanban_params.dart';

// os schemas EtapaKanban, AtendimentoKanban e CapacidadeDoDia do contrato

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
      pronto: json['pronto'] as bool? ?? false,
    );
  }

  // o corpo de criação e edição (EtapaKanbanRequest); pronto só muda pela
  // ação pronto/
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
    final prontoEm = json['pronto_em'] as String?;
    final criadoEm = json['criado_em'] as String?;
    // no avulso o objeto, o nome e o telefone do cliente vêm nulos
    final objeto = json['objeto_detalhe'] as Map<String, dynamic>?;
    return AtendimentoKanban(
      id: json['id'] as int,
      etapaId: json['etapa'] as int,
      etapaNome: json['etapa_nome'] as String? ?? '',
      objeto: objeto == null ? null : objetoDoJson(objeto),
      identificacao: json['identificacao'] as String? ?? '',
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
      acrescimo: dinheiroDaApi(json['acrescimo'] as String? ?? '0'),
      acrescimoMotivo: json['acrescimo_motivo'] as String? ?? '',
      pagamentos: (json['pagamentos'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(pagamentoDoJson)
          .toList(),
      minutosExtras: json['minutos_extras'] as int? ?? 0,
      duracaoPrevista: json['duracao_prevista'] as int?,
      prontoEm: prontoEm == null ? null : dataHoraDaApi(prontoEm),
      criadoEm: criadoEm == null ? null : dataHoraDaApi(criadoEm),
    );
  }

  // o corpo do POST (AtendimentoKanbanRequest). no avulso o objeto vai nulo
  // e a identificação vai no lugar; ignorar_limite só vai quando o dono
  // mandou receber mesmo assim
  static Map<String, dynamic> corpoDeCriacao(NovoAtendimentoParams params) {
    return {
      'etapa': params.etapaId,
      'objeto': params.objetoId,
      if (params.identificacao.isNotEmpty)
        'identificacao': params.identificacao,
      'servico': params.servicoId,
      'data': dataParaApi(params.data),
      'horario_entrada': params.horarioEntrada == null
          ? null
          : horaParaApi(params.horarioEntrada!),
      'colaborador': ?params.colaboradorId,
      'observacao': params.observacao,
      if (params.ignorarLimite) 'ignorar_limite': true,
    };
  }

  // o corpo do PATCH de remarcar: o dia e a hora (null é sem hora marcada)
  static Map<String, dynamic> corpoDeRemarcacao(
    RemarcarAtendimentoKanbanParams params,
  ) {
    return {
      'data': dataParaApi(params.data),
      'horario_entrada': params.horarioEntrada == null
          ? null
          : horaParaApi(params.horarioEntrada!),
      if (params.ignorarLimite) 'ignorar_limite': true,
    };
  }
}

class CapacidadeDoDiaModel {
  const CapacidadeDoDiaModel(this.json);

  final Map<String, dynamic> json;

  factory CapacidadeDoDiaModel.fromJson(Map<String, dynamic> json) =>
      CapacidadeDoDiaModel(json);

  CapacidadeDoDia toEntity() {
    return CapacidadeDoDia(
      data: dataDaApi(json['data'] as String),
      capacidade: json['capacidade'] as int?,
      vagas: json['vagas'] as int? ?? 1,
      ajustado: json['ajustado'] as bool? ?? false,
      ocupados: json['ocupados'] as int? ?? 0,
    );
  }

  // o corpo do PUT (AjusteDoDiaRequest): a capacidade vai mesmo nula, que
  // é "sem máximo"
  static Map<String, dynamic> corpoDeAjuste(AjustarCapacidadeParams params) => {
    'capacidade': params.capacidade,
    'vagas': params.vagas,
  };
}
