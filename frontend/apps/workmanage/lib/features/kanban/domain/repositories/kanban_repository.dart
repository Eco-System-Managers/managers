import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';

import '../entities/atendimento_kanban.dart';
import '../entities/etapa.dart';
import '../params/kanban_params.dart';

// contrato da esteira: o domain diz O QUE precisa, o data decide COMO. toda
// falha volta como Left(Failure), com a mensagem que a tela mostra
abstract class KanbanRepository {
  // as colunas, na ordem do quadro
  Future<Either<Failure, List<Etapa>>> listarEtapas();

  // cria quando o id é 0, senão edita
  Future<Either<Failure, Etapa>> salvarEtapa(Etapa etapa);

  // 400 etapa_com_atendimentos quando ainda há cards nela
  Future<Either<Failure, void>> removerEtapa(int id);

  // os ids na nova ordem
  Future<Either<Failure, void>> reordenarEtapas(List<int> ids);

  // o quadro de um dia, inteiro
  Future<Either<Failure, List<AtendimentoKanban>>> listarDoDia(DateTime data);

  Future<Either<Failure, List<AtendimentoKanban>>> listarDoCliente(
    int clienteId,
  );

  Future<Either<Failure, AtendimentoKanban>> obter(int id);

  // 400 horario_ocupado quando a hora de entrada já tem alguém
  Future<Either<Failure, AtendimentoKanban>> criar(
    NovoAtendimentoParams params,
  );

  Future<Either<Failure, AtendimentoKanban>> mover(
    MoverAtendimentoParams params,
  );

  Future<Either<Failure, AtendimentoKanban>> cobrar(CobrancaParams params);

  Future<Either<Failure, AtendimentoKanban>> desfazerCobranca(int id);

  // 400 falta_em_pago quando já foi cobrado
  Future<Either<Failure, AtendimentoKanban>> marcarFalta(int id);

  Future<Either<Failure, AtendimentoKanban>> desfazerFalta(int id);

  // a esteira não tem "cancelado": registrado por engano, apaga
  Future<Either<Failure, void>> remover(int id);

  // as horas de entrada livres do dia, pela capacidade do expediente
  Future<Either<Failure, List<Hora>>> slots(DateTime data);
}
