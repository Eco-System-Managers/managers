import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../domain/entities/assinatura.dart';
import '../../domain/entities/oferta_de_plano.dart';

// a loja do aparelho, pelo SDK do RevenueCat. no painel do RevenueCat há uma
// offering por plano (pro, business, enterprise), cada uma com os pacotes
// mensal, semestral e anual. não trata erro: a PlatformException do SDK sobe
// para o repository
abstract class LojaDataSource {
  Future<List<OfertaDePlano>> ofertas(String negocio);

  Future<void> comprar(OfertaDePlano oferta, String negocio);

  Future<void> restaurar(String negocio);

  Future<String?> linkDeGerenciar(String negocio);
}

class LojaRevenueCatDataSource implements LojaDataSource {
  LojaRevenueCatDataSource(this._apiKey);

  final String _apiKey;

  // os pacotes da última leitura, pelo id da oferta: o domain não conhece o
  // Package do SDK, e é por ele que a loja compra
  final Map<String, Package> _pacotes = {};

  // o SDK é configurado na primeira vez, já com o negócio; depois, entrar
  // com outro negócio (outra sessão no mesmo aparelho) troca o cliente
  Future<void> _entrar(String negocio) async {
    if (await Purchases.isConfigured) {
      if (await Purchases.appUserID != negocio) await Purchases.logIn(negocio);
      return;
    }
    await Purchases.configure(
      PurchasesConfiguration(_apiKey)..appUserID = negocio,
    );
  }

  @override
  Future<List<OfertaDePlano>> ofertas(String negocio) async {
    await _entrar(negocio);
    final offerings = await Purchases.getOfferings();
    _pacotes.clear();

    final ofertas = <OfertaDePlano>[];
    for (final plano in TipoPlano.values) {
      final offering = offerings.getOffering(plano.name);
      if (offering == null) continue;
      final porPeriodo = {
        PeriodoDoPlano.mensal: offering.monthly,
        PeriodoDoPlano.semestral: offering.sixMonth,
        PeriodoDoPlano.anual: offering.annual,
      };
      for (final MapEntry(key: periodo, value: pacote) in porPeriodo.entries) {
        if (pacote == null) continue;
        final id = '${offering.identifier}/${pacote.identifier}';
        _pacotes[id] = pacote;
        ofertas.add(
          OfertaDePlano(
            id: id,
            plano: plano,
            periodo: periodo,
            // o SDK dá double; vira Decimal na hora, com duas casas
            preco: Decimal.parse(pacote.storeProduct.price.toStringAsFixed(2)),
            precoTexto: pacote.storeProduct.priceString,
          ),
        );
      }
    }
    return ofertas;
  }

  @override
  Future<void> comprar(OfertaDePlano oferta, String negocio) async {
    await _entrar(negocio);
    final pacote = _pacotes[oferta.id];
    if (pacote == null) throw StateError('oferta fora da última leitura');

    // no Google Play, trocar de plano com um ativo é substituir a assinatura,
    // senão viram duas cobranças. na App Store os planos estão num grupo só,
    // e a loja já troca sozinha
    StoreProductChangeInfo? troca;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final ativas = (await Purchases.getCustomerInfo()).activeSubscriptions;
      final atual = ativas
          .where((p) => p != pacote.storeProduct.identifier)
          .firstOrNull;
      if (atual != null) {
        troca = StoreProductChangeInfo(
          atual.split(':').first,
          replacementMode: StoreReplacementMode.withTimeProration,
        );
      }
    }
    await Purchases.purchase(
      PurchaseParams.package(pacote, productChangeInfo: troca),
    );
  }

  @override
  Future<void> restaurar(String negocio) async {
    await _entrar(negocio);
    await Purchases.restorePurchases();
  }

  @override
  Future<String?> linkDeGerenciar(String negocio) async {
    await _entrar(negocio);
    return (await Purchases.getCustomerInfo()).managementURL;
  }
}
