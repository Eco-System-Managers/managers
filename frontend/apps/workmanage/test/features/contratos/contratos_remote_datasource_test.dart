import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/contratos/data/datasources/contratos_remote_datasource.dart';
import 'package:managers/features/contratos/data/models/modelo_contrato_model.dart';

import '../../helpers/fake_adapter.dart';

const _contratoJson = {
  'id': 7,
  'modelo': 2,
  'cliente': 5,
  'cliente_nome': 'Ana',
  'cliente_email': 'ana@x.com',
  'titulo': 'Contrato',
  'corpo': 'Eu, Ana, concordo.',
  'status': 'enviado',
  'token': 'abc',
  'nome_assinante': '',
  'ip_assinante': null,
  'assinado_em': null,
  'criado_em': '2026-10-25T10:00:00-03:00',
  'atualizado_em': '2026-10-25T10:00:00-03:00',
};

Map<String, dynamic> _pagina(List<Object> results) => {
  'count': results.length,
  'next': null,
  'previous': null,
  'results': results,
};

void main() {
  test('listarContratos manda os filtros e lê a página inteira', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, _pagina([_contratoJson])),
    );
    final datasource = ContratosRemoteDataSourceImpl(dioDeTeste(adapter));

    final contratos = await datasource.listarContratos(
      clienteId: 5,
      status: 'enviado',
    );

    final uri = adapter.requisicoes.single.uri;
    expect(uri.path, endsWith('contratos/'));
    expect(uri.queryParameters, {
      'cliente': '5',
      'status': 'enviado',
      'page_size': '100',
    });
    final c = contratos.single.toEntity();
    expect(c.id, 7);
    expect(c.clienteNome, 'Ana');
    expect(c.status.name, 'enviado');
    expect(c.criadoEm.toUtc(), DateTime.utc(2026, 10, 25, 13));
  });

  test('gerar manda modelo e cliente no corpo', () async {
    final adapter = FakeAdapter((_) async => respostaJson(201, _contratoJson));
    final datasource = ContratosRemoteDataSourceImpl(dioDeTeste(adapter));

    final contrato = await datasource.gerar(modeloId: 2, clienteId: 5);

    final req = adapter.requisicoes.single;
    expect(req.path, 'contratos/gerar/');
    expect(req.data, {'modelo_id': 2, 'cliente_id': 5});
    expect(contrato.id, 7);
  });

  test('marcar manda o status e o nome só quando tem', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(200, {..._contratoJson, 'status': 'assinado'}),
    );
    final datasource = ContratosRemoteDataSourceImpl(dioDeTeste(adapter));

    await datasource.marcar(7, 'assinado', nomeAssinante: 'Ana Lima');
    await datasource.marcar(7, 'recusado');

    expect(adapter.requisicoes.first.path, 'contratos/7/marcar/');
    expect(adapter.requisicoes.first.data, {
      'status': 'assinado',
      'nome_assinante': 'Ana Lima',
    });
    expect(adapter.requisicoes.last.data, {'status': 'recusado'});
  });

  test('listarModelos filtra por ativo e o model vai e volta', () async {
    final adapter = FakeAdapter(
      (_) async => respostaJson(
        200,
        _pagina([
          {
            'id': 2,
            'titulo': 'Padrão',
            'corpo': 'Eu, {{cliente_nome}}.',
            'ativo': true,
            'criado_em': '2026-10-25T10:00:00-03:00',
          },
        ]),
      ),
    );
    final datasource = ContratosRemoteDataSourceImpl(dioDeTeste(adapter));

    final modelos = await datasource.listarModelos(ativo: true);

    expect(adapter.requisicoes.single.uri.queryParameters['ativo'], 'true');
    final modelo = modelos.single.toEntity();
    expect(modelo.titulo, 'Padrão');
    // o id não vai no corpo: está na URL
    expect(ModeloContratoModel.fromEntity(modelo).toJson(), {
      'titulo': 'Padrão',
      'corpo': 'Eu, {{cliente_nome}}.',
      'ativo': true,
    });
  });
}
