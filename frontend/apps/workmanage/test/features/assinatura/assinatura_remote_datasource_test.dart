import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/assinatura/data/datasources/assinatura_remote_datasource.dart';
import 'package:managers/features/assinatura/domain/entities/assinatura.dart';

import '../../helpers/fake_adapter.dart';

Map<String, dynamic> _assinaturaJson({
  String status = 'trial',
  bool bloqueada = false,
  bool checkoutAberto = false,
}) => {
  'status': status,
  'plano': 'business',
  'plano_nome': 'Business',
  'inicio': '2026-10-01',
  'proximo_vencimento': '2026-11-01',
  'trial_fim': status == 'trial' ? '2026-10-15' : null,
  'bloqueada': bloqueada,
  'vitalicia': false,
  'limite_equipe': 5,
  'equipe_ativa': 2,
  'checkout_aberto': checkoutAberto,
};

void main() {
  test('obter lê a assinatura, com o trial, o plano e a equipe', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, _assinaturaJson(bloqueada: true)),
    );
    final datasource = AssinaturaRemoteDataSourceImpl(dioDeTeste(adapter));

    final assinatura = await datasource.obter();

    expect(adapter.requisicoes.single.path, 'billing/assinatura/');
    expect(assinatura.status, StatusAssinatura.trial);
    expect(assinatura.plano, TipoPlano.business);
    expect(assinatura.planoNome, 'Business');
    expect(assinatura.trialFim, DateTime(2026, 10, 15));
    expect(assinatura.proximoVencimento, DateTime(2026, 11, 1));
    expect(assinatura.bloqueada, isTrue);
    expect(assinatura.podeAssinar, isTrue);
    expect(assinatura.checkoutAberto, isFalse);
    expect((assinatura.limiteEquipe, assinatura.equipeAtiva), (5, 2));
    expect(assinatura.vitalicia, isFalse);
  });

  test('checkout_aberto vem da API', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, _assinaturaJson(checkoutAberto: true)),
    );
    final datasource = AssinaturaRemoteDataSourceImpl(dioDeTeste(adapter));

    expect((await datasource.obter()).checkoutAberto, isTrue);
  });

  test('sincronizar faz POST e devolve a assinatura lida na loja', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, _assinaturaJson(status: 'ativa')),
    );
    final datasource = AssinaturaRemoteDataSourceImpl(dioDeTeste(adapter));

    final assinatura = await datasource.sincronizar();

    expect(adapter.requisicoes.single.method, 'POST');
    expect(
      adapter.requisicoes.single.path,
      'billing/assinatura/sincronizar/',
    );
    expect(assinatura.status, StatusAssinatura.ativa);
    expect(assinatura.podeAssinar, isFalse);
  });

  test(
    'listarPagamentos segue a paginação e converte valor e status',
    () async {
      final adapter = FakeAdapter(
        (_) async => respostaJson(200, {
          'count': 2,
          'next': null,
          'previous': null,
          'results': [
            {'valor': '49.90', 'status': 'pago', 'data': '2026-10-01'},
            {'valor': '49.90', 'status': 'falhou', 'data': '2026-11-01'},
          ],
        }),
      );
      final datasource = AssinaturaRemoteDataSourceImpl(dioDeTeste(adapter));

      final pagamentos = await datasource.listarPagamentos();

      expect(
        adapter.requisicoes.single.uri.path,
        endsWith('billing/pagamentos/'),
      );
      expect(
        adapter.requisicoes.single.uri.queryParameters['page_size'],
        '100',
      );
      expect(pagamentos.first.valor, Decimal.parse('49.90'));
      expect(pagamentos.first.status, StatusPagamentoAssinatura.pago);
      expect(pagamentos.last.status, StatusPagamentoAssinatura.falhou);
      expect(pagamentos.last.data, DateTime(2026, 11, 1));
    },
  );
}
