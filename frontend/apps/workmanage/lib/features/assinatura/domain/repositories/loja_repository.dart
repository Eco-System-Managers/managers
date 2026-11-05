import 'package:dartz/dartz.dart';
import 'package:managers/core/error/failures.dart';

import '../entities/oferta_de_plano.dart';

// a compra na loja do aparelho (App Store ou Google Play). o cliente da loja
// é o negócio: toda chamada leva o id dele (o schema_name da sessão), e a
// compra feita aqui vale em qualquer aparelho logado no mesmo negócio.
// a pessoa desistir da compra é Left com o code compraCancelada, sem mensagem
abstract class LojaRepository {
  static const compraCancelada = 'compra_cancelada';

  Future<Either<Failure, List<OfertaDePlano>>> ofertas(String negocio);

  Future<Either<Failure, Unit>> comprar(OfertaDePlano oferta, String negocio);

  Future<Either<Failure, Unit>> restaurar(String negocio);

  // onde a pessoa gerencia e cancela a assinatura (a tela da loja); null
  // quando a loja não informa
  Future<Either<Failure, String?>> linkDeGerenciar(String negocio);
}
