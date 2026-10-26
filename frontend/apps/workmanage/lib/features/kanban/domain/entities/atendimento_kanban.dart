import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/clientes/domain/entities/objeto_cliente.dart';
import 'package:managers/features/financeiro/domain/entities/pagamento.dart';

// o card do quadro: um objeto (veículo ou pet) de um cliente, um serviço,
// em alguma etapa. não há status: a posição na etapa é o status; falta e
// pago são marcas à parte
class AtendimentoKanban extends Equatable {
  AtendimentoKanban({
    required this.id,
    required this.etapaId,
    required this.etapaNome,
    required this.objeto,
    required this.clienteNome,
    this.clienteTelefone = '',
    required this.servicoId,
    required this.servicoNome,
    required this.servicoPreco,
    this.servicoDuracao = 0,
    this.colaboradorId,
    this.colaboradorNome = '',
    this.observacao = '',
    this.data,
    this.horarioEntrada,
    this.pago = false,
    this.faltou = false,
    Decimal? desconto,
    this.pagamentos = const [],
    this.criadoEm,
  }) : desconto = desconto ?? Decimal.fromInt(0);

  final int id;
  final int etapaId;
  final String etapaNome;
  final ObjetoCliente objeto;
  final String clienteNome;
  final String clienteTelefone;
  final int servicoId;
  final String servicoNome;

  // o preço do catálogo na hora da leitura: a esteira não congela preço
  final Decimal servicoPreco;
  final int servicoDuracao;

  // quem pegou o carro ou o pet; opcional
  final int? colaboradorId;
  final String colaboradorNome;
  final String observacao;

  // o dia do quadro; a API usa hoje quando não vem
  final DateTime? data;

  // opcional: dá para receber sem hora marcada
  final Hora? horarioEntrada;
  final bool pago;
  final bool faltou;
  final Decimal desconto;
  final List<Pagamento> pagamentos;
  final DateTime? criadoEm;

  int get clienteId => objeto.clienteId;

  Decimal get valorTotal => servicoPreco - desconto;

  Decimal get valorPago =>
      pagamentos.fold(Decimal.fromInt(0), (soma, p) => soma + p.valor);

  @override
  List<Object?> get props => [
    id,
    etapaId,
    etapaNome,
    objeto,
    clienteNome,
    clienteTelefone,
    servicoId,
    servicoNome,
    servicoPreco,
    servicoDuracao,
    colaboradorId,
    colaboradorNome,
    observacao,
    data,
    horarioEntrada,
    pago,
    faltou,
    desconto,
    pagamentos,
    criadoEm,
  ];
}
