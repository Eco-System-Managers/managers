import 'package:decimal/decimal.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/features/clientes/domain/entities/porte.dart';
import 'package:managers/features/empresa/domain/entities/nicho.dart';

import '../../domain/entities/servico.dart';

// o schema Servico do contrato. preço e taxa vêm como string decimal
// ("45.50"); a taxa sem tipo vem como ''. o nicho é slug; o porte vem ''
// quando o serviço vale para qualquer um
class ServicoModel {
  const ServicoModel({
    required this.id,
    required this.nome,
    required this.nicho,
    required this.porte,
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
  final String nicho;
  final String porte;
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
      nicho: json['nicho'] as String? ?? '',
      porte: json['porte'] as String? ?? '',
      descricao: json['descricao'] as String? ?? '',
      duracao: json['duracao'] as int,
      preco: json['preco'] as String,
      taxaCancelamentoTipo: json['taxa_cancelamento_tipo'] as String? ?? '',
      taxaCancelamentoValor: json['taxa_cancelamento_valor'] as String? ?? '0',
      ativo: json['ativo'] as bool? ?? true,
      colaboradores: (json['colaboradores'] as List? ?? const []).cast<int>(),
    );
  }

  // o id não vai: ele está na URL. o ativo vai, para inativar pelo PATCH.
  // sem nicho, a API usa o único do negócio
  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      if (nicho.isNotEmpty) 'nicho': nicho,
      'porte': porte,
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
      nicho: servico.nicho?.slug ?? '',
      porte: servico.porte?.name ?? '',
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
      nicho: Nicho.doSlug(nicho),
      porte: Porte.daApi(porte),
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
