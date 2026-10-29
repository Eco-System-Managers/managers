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
  'plano_nome': 'Pro',
  'inicio': '2026-10-01',
  'proximo_vencimento': '2026-11-01',
  'trial_fim': status == 'trial' ? '2026-10-15' : null,
  'bloqueada': bloqueada,
  'checkout_aberto': checkoutAberto,
};

void main() {
  test('obter lê a assinatura, com o trial e o bloqueio', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, _assinaturaJson(bloqueada: true)),
    );
    final datasource = AssinaturaRemoteDataSourceImpl(dioDeTeste(adapter));

    final assinatura = await datasource.obter();

    expect(adapter.requisicoes.single.path, 'billing/assinatura/');
    expect(assinatura.status, StatusAssinatura.trial);
    expect(assinatura.planoNome, 'Pro');
    expect(assinatura.trialFim, DateTime(2026, 10, 15));
    expect(assinatura.proximoVencimento, DateTime(2026, 11, 1));
    expect(assinatura.bloqueada, isTrue);
    expect(assinatura.podeAssinar, isTrue);
    expect(assinatura.checkoutAberto, isFalse);
  });

  test('checkout_aberto vem da API', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, _assinaturaJson(checkoutAberto: true)),
    );
    final datasource = AssinaturaRemoteDataSourceImpl(dioDeTeste(adapter));

    expect((await datasource.obter()).checkoutAberto, isTrue);
  });

  test('iniciar devolve o link do checkout', () async {
    final adapter = FakeAdapter(
      (_) async =>
          respostaJson(200, {'link_checkout': 'https://mp.test/checkout/1'}),
    );
    final datasource = AssinaturaRemoteDataSourceImpl(dioDeTeste(adapter));

    final link = await datasource.iniciar();

    expect(link, 'https://mp.test/checkout/1');
    expect(adapter.requisicoes.single.method, 'POST');
    expect(adapter.requisicoes.single.path, 'billing/assinatura/iniciar/');
  });

  test('confirmar manda o id_externo e cancelar faz POST sem corpo', () async {
    final adapter = FakeAdapter((options) async {
      final status = options.path.endsWith('cancelar/') ? 'cancelada' : 'ativa';
      return respostaJson(200, _assinaturaJson(status: status));
    });
    final datasource = AssinaturaRemoteDataSourceImpl(dioDeTeste(adapter));

    final ativa = await datasource.confirmar('pre-123');
    final cancelada = await datasource.cancelar();

    expect(ativa.status, StatusAssinatura.ativa);
    expect(ativa.podeAssinar, isFalse);
    expect(cancelada.status, StatusAssinatura.cancelada);
    expect(adapter.requisicoes[0].path, 'billing/assinatura/confirmar/');
    expect(adapter.requisicoes[0].data, {'id_externo': 'pre-123'});
    expect(adapter.requisicoes[1].method, 'POST');
    expect(adapter.requisicoes[1].path, 'billing/assinatura/cancelar/');
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
