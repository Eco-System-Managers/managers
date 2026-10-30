import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:managers/features/clientes/domain/entities/porte.dart';
import 'package:managers/features/empresa/domain/entities/nicho.dart';

// como a taxa de cancelamento é cobrada: valor fixo em reais ou percentual
// do preço. nos dois o teto é 30% (regra do backend); null é sem taxa
enum TipoTaxaCancelamento { valor, percentual }

// um item do catálogo: o que o negócio vende, por quanto e em quanto tempo
class Servico extends Equatable {
  Servico({
    this.id = 0,
    required this.nome,
    this.nicho,
    this.porte,
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

  // a pasta do serviço: um dos nichos do negócio. null num serviço novo
  // de negócio com um nicho só, que a API preenche com ele
  final Nicho? nicho;

  // só na esteira: o porte do veículo ou do pet que o serviço atende
  // ("Lavagem simples · Moto"). null vale para qualquer porte
  final Porte? porte;

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

  // se atende um veículo ou pet deste porte, a mesma regra da API: serviço
  // sem porte atende qualquer um, e objeto sem porte (cadastro de antes
  // dele) aceita qualquer serviço, porque não há com o que comparar
  bool servePara(Porte? porteDoObjeto) =>
      porte == null || porteDoObjeto == null || porte == porteDoObjeto;

  Servico copyWith({
    int? id,
    String? nome,
    Nicho? nicho,
    Porte? porte,
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
      nicho: nicho ?? this.nicho,
      porte: porte ?? this.porte,
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
    nicho,
    porte,
    descricao,
    duracao,
    preco,
    taxaCancelamentoTipo,
    taxaCancelamentoValor,
    ativo,
    colaboradores,
  ];
}
