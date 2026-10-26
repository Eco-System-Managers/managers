import 'package:managers/core/utils/datas.dart';

// receber um atendimento: entra numa etapa (a primeira), com o objeto do
// cliente e um serviço. a hora de entrada é opcional
class NovoAtendimentoParams {
  const NovoAtendimentoParams({
    required this.etapaId,
    required this.objetoId,
    required this.servicoId,
    required this.data,
    this.horarioEntrada,
    this.colaboradorId,
    this.observacao = '',
  });

  final int etapaId;
  final int objetoId;
  final int servicoId;
  final DateTime data;
  final Hora? horarioEntrada;

  // quem pega o carro ou o pet; opcional
  final int? colaboradorId;
  final String observacao;
}

// o quadro de um dia, inteiro ou só os cards de um profissional
class ListarDoDiaParams {
  const ListarDoDiaParams({required this.data, this.colaboradorId});

  final DateTime data;
  final int? colaboradorId;
}

class MoverAtendimentoParams {
  const MoverAtendimentoParams({required this.id, required this.etapaId});

  final int id;
  final int etapaId;
}
