import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:managers/core/error/failures.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../domain/entities/oferta_de_plano.dart';
import '../../domain/repositories/loja_repository.dart';
import '../datasources/loja_datasource.dart';

class LojaRepositoryImpl implements LojaRepository {
  LojaRepositoryImpl(this._dataSource);

  final LojaDataSource _dataSource;

  @override
  Future<Either<Failure, List<OfertaDePlano>>> ofertas(String negocio) =>
      _executar(() => _dataSource.ofertas(negocio));

  @override
  Future<Either<Failure, Unit>> comprar(
    OfertaDePlano oferta,
    String negocio,
  ) => _executar(() async {
    await _dataSource.comprar(oferta, negocio);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> restaurar(String negocio) =>
      _executar(() async {
        await _dataSource.restaurar(negocio);
        return unit;
      });

  @override
  Future<Either<Failure, String?>> linkDeGerenciar(String negocio) =>
      _executar(() => _dataSource.linkDeGerenciar(negocio));

  // a loja fala por PlatformException com o código do RevenueCat. desistir
  // não é erro para a tela: vem com o code, sem mensagem
  Future<Either<Failure, T>> _executar<T>(Future<T> Function() acao) async {
    try {
      return Right(await acao());
    } on PlatformException catch (e) {
      return Left(switch (PurchasesErrorHelper.getErrorCode(e)) {
        PurchasesErrorCode.purchaseCancelledError => const ServerFailure(
          message: '',
          code: LojaRepository.compraCancelada,
        ),
        PurchasesErrorCode.networkError => const NetworkFailure(),
        PurchasesErrorCode.paymentPendingError => const ServerFailure(
          message:
              'O pagamento está aguardando a confirmação da loja. O acesso '
              'libera assim que ela confirmar.',
          code: 'pagamento_pendente',
        ),
        PurchasesErrorCode.productAlreadyPurchasedError => const ServerFailure(
          message: 'Você já tem este plano. Toque em "Restaurar compras".',
          code: 'ja_comprado',
        ),
        _ => const ServerFailure(
          message: 'A loja não concluiu a operação. Tente novamente.',
          code: 'loja_erro',
        ),
      });
    } catch (_) {
      return const Left(
        ServerFailure(
          message: 'A loja não está disponível agora. Tente novamente.',
          code: 'loja_erro',
        ),
      );
    }
  }
}
