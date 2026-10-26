import 'package:decimal/decimal.dart';

import '../../domain/entities/colaborador.dart';
import '../../domain/params/equipe_params.dart';

// o schema Colaborador do contrato: nome e e-mail vêm prontos (o e-mail é
// vazio para quem não tem login), o papel vem como texto ou null
class ColaboradorModel {
  const ColaboradorModel(this.json);

  final Map<String, dynamic> json;

  factory ColaboradorModel.fromJson(Map<String, dynamic> json) =>
      ColaboradorModel(json);

  Colaborador toEntity() {
    final comissao = json['comissao_percentual'] as String?;
    return Colaborador(
      id: json['id'] as int,
      nome: json['nome'] as String? ?? '',
      email: json['email'] as String? ?? '',
      temAcesso: json['tem_acesso'] as bool? ?? false,
      funcao: json['funcao'] as String? ?? '',
      tipo: VinculoColaborador.daApi(json['tipo'] as String?),
      comissaoPercentual: comissao == null ? null : Decimal.tryParse(comissao),
      podeCobrar: json['pode_cobrar'] as bool? ?? true,
      papel: Papel.values.asNameMap()[json['papel'] as String?],
      ativo: json['ativo'] as bool? ?? true,
    );
  }

  // o corpo de criação e edição (ColaboradorRequest). a comissão vai como
  // string decimal, como todo número da API
  static Map<String, dynamic> corpo(DadosColaborador dados) => {
    'nome': dados.nome,
    'funcao': dados.funcao,
    'tipo': dados.tipo.name,
    'comissao_percentual': dados.comissaoPercentual?.toStringAsFixed(2),
    'pode_cobrar': dados.podeCobrar,
  };
}
