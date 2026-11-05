import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../entities/assinatura.dart';
import '../entities/oferta_de_plano.dart';
import '../repositories/assinatura_repository.dart';
import '../repositories/loja_repository.dart';

// os use cases da assinatura, um por ação, no mesmo arquivo porque cada um
// é poucas linhas sobre os repositories. o parâmetro String é o negócio (o
// schema_name da sessão), que é o cliente da loja

class ObterAssinaturaUseCase implements UseCase<Assinatura, NoParams> {
  const ObterAssinaturaUseCase(this._repository);

  final AssinaturaRepository _repository;

  @override
  Future<Either<Failure, Assinatura>> call(NoParams params) =>
      _repository.obter();
}

class ListarPagamentosAssinaturaUseCase
    implements UseCase<List<PagamentoAssinatura>, NoParams> {
  const ListarPagamentosAssinaturaUseCase(this._repository);

  final AssinaturaRepository _repository;

  @override
  Future<Either<Failure, List<PagamentoAssinatura>>> call(NoParams params) =>
      _repository.listarPagamentos();
}

// os planos à venda na loja, com o preço dela
class ListarOfertasUseCase implements UseCase<List<OfertaDePlano>, String> {
  const ListarOfertasUseCase(this._loja);

  final LojaRepository _loja;

  @override
  Future<Either<Failure, List<OfertaDePlano>>> call(String params) =>
      _loja.ofertas(params);
}

class ComprarPlanoParams {
  const ComprarPlanoParams({required this.oferta, required this.negocio});

  final OfertaDePlano oferta;
  final String negocio;
}

// compra na loja e já pede à API a assinatura nova. se a loja cobrou e a
// API não respondeu, a compra não se perde: o aviso da loja chega ao
// servidor sozinho, e "Restaurar compras" lê de novo
class ComprarPlanoUseCase implements UseCase<Assinatura, ComprarPlanoParams> {
  const ComprarPlanoUseCase(this._loja, this._assinatura);

  final LojaRepository _loja;
  final AssinaturaRepository _assinatura;

  @override
  Future<Either<Failure, Assinatura>> call(ComprarPlanoParams params) async {
    final compra = await _loja.comprar(params.oferta, params.negocio);
    return compra.fold(
      (failure) async => Left(failure),
      (_) => _assinatura.sincronizar(),
    );
  }
}

// a compra feita antes (outro aparelho, app reinstalado) volta para o negócio
class RestaurarComprasUseCase implements UseCase<Assinatura, String> {
  const RestaurarComprasUseCase(this._loja, this._assinatura);

  final LojaRepository _loja;
  final AssinaturaRepository _assinatura;

  @override
  Future<Either<Failure, Assinatura>> call(String params) async {
    final restaurou = await _loja.restaurar(params);
    return restaurou.fold(
      (failure) async => Left(failure),
      (_) => _assinatura.sincronizar(),
    );
  }
}

class LinkDeGerenciarUseCase implements UseCase<String?, String> {
  const LinkDeGerenciarUseCase(this._loja);

  final LojaRepository _loja;

  @override
  Future<Either<Failure, String?>> call(String params) =>
      _loja.linkDeGerenciar(params);
}
