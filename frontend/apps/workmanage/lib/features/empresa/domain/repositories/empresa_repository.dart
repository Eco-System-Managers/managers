// contrato da empresa: o domain diz O QUE precisa, o data decide COMO.
// toda falha volta como Left(Failure), com a mensagem que a tela mostra
import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';

import '../entities/empresa_config.dart';
import '../entities/endereco.dart';
import '../entities/horario_funcionamento.dart';

abstract class EmpresaRepository {
  // a config atual: é com ela que o wizard continua de onde parou e que
  // as configurações abrem preenchidas
  Future<Either<Failure, EmpresaConfig>> buscarConfig();

  // devolve a config salva, já com o tipo de agenda que o backend definiu
  Future<Either<Failure, EmpresaConfig>> salvarConfig(EmpresaConfig config);

  Future<Either<Failure, Endereco>> buscarEnderecoPorCep(String cep);

  // os sete dias da semana, abertos ou fechados
  Future<Either<Failure, List<HorarioFuncionamento>>> buscarHorarios();

  Future<Either<Failure, List<HorarioFuncionamento>>> salvarHorarios(
    List<HorarioFuncionamento> horarios,
  );

  // separado do salvarConfig: concluir tem regra própria no backend
  // (exige o documento e cria o colaborador do dono e as etapas do kanban)
  Future<Either<Failure, EmpresaConfig>> concluir();

  // devolve a URL pública da logo nova
  Future<Either<Failure, String>> enviarLogo(
    List<int> bytes,
    String nomeArquivo,
  );
}
