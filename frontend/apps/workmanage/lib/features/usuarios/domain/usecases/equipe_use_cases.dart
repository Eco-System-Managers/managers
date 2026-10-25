import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/session/sessao.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/colaborador.dart';
import '../entities/convite.dart';
import '../params/equipe_params.dart';
import '../repositories/usuarios_repository.dart';

// os use cases da gestão da equipe (fase 4), um por ação, no mesmo arquivo
// porque cada um é uma linha sobre o repository

class ObterColaboradorUseCase implements UseCase<Colaborador, int> {
  const ObterColaboradorUseCase(this._repository);

  final UsuariosRepository _repository;

  @override
  Future<Either<Failure, Colaborador>> call(int params) =>
      _repository.obterColaborador(params);
}

class AtualizarFuncaoUseCase
    implements UseCase<Colaborador, AtualizarFuncaoParams> {
  const AtualizarFuncaoUseCase(this._repository);

  final UsuariosRepository _repository;

  @override
  Future<Either<Failure, Colaborador>> call(AtualizarFuncaoParams params) =>
      _repository.atualizarFuncao(params.id, params.funcao);
}

class AlterarAtivoColaboradorUseCase
    implements UseCase<void, AlterarAtivoColaboradorParams> {
  const AlterarAtivoColaboradorUseCase(this._repository);

  final UsuariosRepository _repository;

  @override
  Future<Either<Failure, void>> call(AlterarAtivoColaboradorParams params) =>
      params.ativo
      ? _repository.ativarColaborador(params.id)
      : _repository.desativarColaborador(params.id);
}

// quantos agendamentos futuros ficariam sem profissional
class ContarAgendamentosPendentesUseCase implements UseCase<int, int> {
  const ContarAgendamentosPendentesUseCase(this._repository);

  final UsuariosRepository _repository;

  @override
  Future<Either<Failure, int>> call(int params) =>
      _repository.contarAgendamentosPendentes(params);
}

class RemoverColaboradorUseCase implements UseCase<void, int> {
  const RemoverColaboradorUseCase(this._repository);

  final UsuariosRepository _repository;

  @override
  Future<Either<Failure, void>> call(int params) =>
      _repository.removerColaborador(params);
}

class ListarConvitesUseCase implements UseCase<List<Convite>, NoParams> {
  const ListarConvitesUseCase(this._repository);

  final UsuariosRepository _repository;

  @override
  Future<Either<Failure, List<Convite>>> call(NoParams params) =>
      _repository.listarConvites();
}

class CriarConviteUseCase implements UseCase<Convite, NovoConviteParams> {
  const CriarConviteUseCase(this._repository);

  final UsuariosRepository _repository;

  @override
  Future<Either<Failure, Convite>> call(NovoConviteParams params) =>
      _repository.criarConvite(nome: params.nome, email: params.email);
}

class CancelarConviteUseCase implements UseCase<void, int> {
  const CancelarConviteUseCase(this._repository);

  final UsuariosRepository _repository;

  @override
  Future<Either<Failure, void>> call(int params) =>
      _repository.cancelarConvite(params);
}

// rota pública: quem abre o link ainda não tem sessão
class ObterConviteUseCase implements UseCase<ConviteInfo, String> {
  const ObterConviteUseCase(this._repository);

  final UsuariosRepository _repository;

  @override
  Future<Either<Failure, ConviteInfo>> call(String params) =>
      _repository.obterConvite(params);
}

class AceitarConviteUseCase implements UseCase<Sessao, AceitarConviteParams> {
  const AceitarConviteUseCase(this._repository);

  final UsuariosRepository _repository;

  @override
  Future<Either<Failure, Sessao>> call(AceitarConviteParams params) =>
      _repository.aceitarConvite(token: params.token, senha: params.senha);
}
