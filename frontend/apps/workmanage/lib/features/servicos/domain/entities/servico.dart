import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

// como a taxa de cancelamento é cobrada: valor fixo em reais ou percentual
// do preço. nos dois o teto é 30% (regra do backend); null é sem taxa
enum TipoTaxaCancelamento { valor, percentual }

// um item do catálogo: o que o negócio vende, por quanto e em quanto tempo
class Servico extends Equatable {
  Servico({
    this.id = 0,
    required this.nome,
    this.descricao = '',
    required this.duracao,
    required this.preco,
    this.taxaCancelamentoTipo,
    Decimal? taxaCancelamentoValor,
    this.ativo = true,
    this.colaboradores = const [],
  }) : taxaCancelamentoValor = taxaCancelamentoValor ?? Decimal.fromInt(0);

  // 0 enquanto não existe na API
  final int id;
  final String nome;
  final String descricao;

  // em minutos: é o que define conflito de horário na agenda
  final int duracao;
  final Decimal preco;

  final TipoTaxaCancelamento? taxaCancelamentoTipo;

  // reais ou porcentagem, conforme o tipo
  final Decimal taxaCancelamentoValor;

  // desativar tira da vitrine na hora
  final bool ativo;

  // ids dos colaboradores que executam. vazio = qualquer um
  final List<int> colaboradores;

  bool get ehNovo => id == 0;

  Servico copyWith({
    int? id,
    String? nome,
    String? descricao,
    int? duracao,
    Decimal? preco,
    TipoTaxaCancelamento? taxaCancelamentoTipo,
    bool semTaxa = false,
    Decimal? taxaCancelamentoValor,
    bool? ativo,
    List<int>? colaboradores,
  }) {
    return Servico(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      duracao: duracao ?? this.duracao,
      preco: preco ?? this.preco,
      // semTaxa limpa o tipo; sem ele, null significa "não mexer"
      taxaCancelamentoTipo: semTaxa
          ? null
          : taxaCancelamentoTipo ?? this.taxaCancelamentoTipo,
      taxaCancelamentoValor:
          taxaCancelamentoValor ?? this.taxaCancelamentoValor,
      ativo: ativo ?? this.ativo,
      colaboradores: colaboradores ?? this.colaboradores,
    );
  }

  @override
  List<Object?> get props => [
    id,
    nome,
    descricao,
    duracao,
    preco,
    taxaCancelamentoTipo,
    taxaCancelamentoValor,
    ativo,
    colaboradores,
  ];
}
