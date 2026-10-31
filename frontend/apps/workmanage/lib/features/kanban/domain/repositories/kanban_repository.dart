import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';

import '../entities/atendimento_kanban.dart';
import '../entities/capacidade_do_dia.dart';
import '../entities/etapa.dart';
import '../params/kanban_params.dart';

// contrato da esteira: o domain diz O QUE precisa, o data decide COMO. toda
// falha volta como Left(Failure), com a mensagem que a tela mostra
abstract class KanbanRepository {
  // as colunas, na ordem do quadro
  Future<Either<Failure, List<Etapa>>> listarEtapas();

  // cria quando o id é 0, senão edita
  Future<Either<Failure, Etapa>> salvarEtapa(Etapa etapa);

  // 400 etapa_com_atendimentos quando ainda há cards nela; 400 etapa_pronto
  // quando é a de pronto e há outras no quadro
  Future<Either<Failure, void>> removerEtapa(int id);

  // os ids na nova ordem
  Future<Either<Failure, void>> reordenarEtapas(List<int> ids);

  // esta passa a ser a etapa de pronto (a anterior é desmarcada)
  Future<Either<Failure, Etapa>> marcarEtapaPronto(int id);

  // o quadro de um dia, inteiro
  Future<Either<Failure, List<AtendimentoKanban>>> listarDoDia(
    DateTime data, {
    int? colaboradorId,
  });

  Future<Either<Failure, List<AtendimentoKanban>>> listarDoCliente(
    int clienteId,
  );

  Future<Either<Failure, AtendimentoKanban>> obter(int id);

  // 400 dia_lotado quando o dia está no máximo e 400 horario_ocupado quando
  // não há vaga na hora de entrada; com ignorarLimite o dono recebe assim
  // mesmo
  Future<Either<Failure, AtendimentoKanban>> criar(
    NovoAtendimentoParams params,
  );

  Future<Either<Failure, AtendimentoKanban>> mover(
    MoverAtendimentoParams params,
  );

  // os mesmos dia_lotado e horario_ocupado do criar, no dia de destino
  Future<Either<Failure, AtendimentoKanban>> remarcar(
    RemarcarAtendimentoKanbanParams params,
  );

  Future<Either<Failure, AtendimentoKanban>> ajustarTempo(
    AjustarTempoParams params,
  );

  Future<Either<Failure, AtendimentoKanban>> cobrar(CobrancaParams params);

  Future<Either<Failure, AtendimentoKanban>> desfazerCobranca(int id);

  // 400 falta_em_pago quando já foi cobrado
  Future<Either<Failure, AtendimentoKanban>> marcarFalta(int id);

  Future<Either<Failure, AtendimentoKanban>> desfazerFalta(int id);

  // a esteira não tem "cancelado": registrado por engano, apaga
  Future<Either<Failure, void>> remover(int id);

  // as horas de entrada em que o serviço cabe no dia, pelas vagas e pelo
  // máximo do dia
  Future<Either<Failure, List<Hora>>> slots(SlotsKanbanParams params);

  // quanto cabe no dia e quanto já há nele
  Future<Either<Failure, CapacidadeDoDia>> capacidadeDoDia(DateTime data);

  // só o proprietário (403 para os outros)
  Future<Either<Failure, CapacidadeDoDia>> ajustarCapacidade(
    AjustarCapacidadeParams params,
  );

  // apaga o ajuste da data: volta ao padrão da semana
  Future<Either<Failure, CapacidadeDoDia>> desfazerAjuste(DateTime data);
}
