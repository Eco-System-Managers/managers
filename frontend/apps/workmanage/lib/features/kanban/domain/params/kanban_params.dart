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
    this.observacao = '',
  });

  final int etapaId;
  final int objetoId;
  final int servicoId;
  final DateTime data;
  final Hora? horarioEntrada;
  final String observacao;
}

class MoverAtendimentoParams {
  const MoverAtendimentoParams({required this.id, required this.etapaId});

  final int id;
  final int etapaId;
}
