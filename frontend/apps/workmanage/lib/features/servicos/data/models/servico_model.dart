import 'package:decimal/decimal.dart';
import 'package:managers/core/utils/dinheiro.dart';

import '../../domain/entities/servico.dart';

// o schema Servico do contrato. preço e taxa vêm como string decimal
// ("45.50"); a taxa sem tipo vem como ''
class ServicoModel {
  const ServicoModel({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.duracao,
    required this.preco,
    required this.taxaCancelamentoTipo,
    required this.taxaCancelamentoValor,
    required this.ativo,
    required this.colaboradores,
  });

  final int id;
  final String nome;
  final String descricao;
  final int duracao;
  final String preco;
  final String taxaCancelamentoTipo;
  final String taxaCancelamentoValor;
  final bool ativo;
  final List<int> colaboradores;

  factory ServicoModel.fromJson(Map<String, dynamic> json) {
    return ServicoModel(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      descricao: json['descricao'] as String? ?? '',
      duracao: json['duracao'] as int,
      preco: json['preco'] as String,
      taxaCancelamentoTipo: json['taxa_cancelamento_tipo'] as String? ?? '',
      taxaCancelamentoValor: json['taxa_cancelamento_valor'] as String? ?? '0',
      ativo: json['ativo'] as bool? ?? true,
      colaboradores: (json['colaboradores'] as List? ?? const []).cast<int>(),
    );
  }

  // o id não vai: ele está na URL. o ativo vai, para inativar pelo PATCH
  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'descricao': descricao,
      'duracao': duracao,
      'preco': preco,
      'taxa_cancelamento_tipo': taxaCancelamentoTipo,
      'taxa_cancelamento_valor': taxaCancelamentoValor,
      'ativo': ativo,
      'colaboradores': colaboradores,
    };
  }

  factory ServicoModel.fromEntity(Servico servico) {
    return ServicoModel(
      id: servico.id,
      nome: servico.nome,
      descricao: servico.descricao,
      duracao: servico.duracao,
      preco: dinheiroParaApi(servico.preco),
      taxaCancelamentoTipo: servico.taxaCancelamentoTipo?.name ?? '',
      taxaCancelamentoValor: dinheiroParaApi(servico.taxaCancelamentoValor),
      ativo: servico.ativo,
      colaboradores: servico.colaboradores,
    );
  }

  Servico toEntity() {
    return Servico(
      id: id,
      nome: nome,
      descricao: descricao,
      duracao: duracao,
      preco: dinheiroDaApi(preco),
      taxaCancelamentoTipo: TipoTaxaCancelamento.values
          .asNameMap()[taxaCancelamentoTipo],
      taxaCancelamentoValor:
          Decimal.tryParse(taxaCancelamentoValor) ?? Decimal.fromInt(0),
      ativo: ativo,
      colaboradores: colaboradores,
    );
  }
}
