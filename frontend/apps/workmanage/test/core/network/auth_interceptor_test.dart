import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/network/auth_interceptor.dart';
import 'package:managers/core/session/sessao_controller.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/fake_sessao_repository.dart';

void main() {
  late SessaoController sessao;
  late FakeAdapter api;
  late FakeAdapter renovacao;
  late Dio dio;

  // a API: responde conforme o token que chegou. o access-1 "expirou"
  Future<ResponseBody> apiPadrao(RequestOptions options) async {
    final auth = options.headers['Authorization'];
    if (auth == 'Bearer ${sessaoRenovada.access}') {
      return respostaJson(200, {'ok': true});
    }
    return respostaErro(401, 'token_invalido', detail: 'Token expirado.');
  }

  // o refresh: devolve a sessão renovada
  Future<ResponseBody> renovacaoOk(RequestOptions options) async {
    return respostaJson(200, sessaoJson(sessaoRenovada));
  }

  Dio montar({
    Future<ResponseBody> Function(RequestOptions)? apiHandler,
    Future<ResponseBody> Function(RequestOptions)? renovacaoHandler,
  }) {
    api = FakeAdapter(apiHandler ?? apiPadrao);
    renovacao = FakeAdapter(renovacaoHandler ?? renovacaoOk);
    dio = dioDeTeste(api);
    dio.interceptors.add(
      AuthInterceptor(
        sessao: sessao,
        dio: dio,
        dioRenovacao: dioDeTeste(renovacao),
      ),
    );
    return dio;
  }

  setUp(() async {
    sessao = SessaoController(FakeSessaoRepository());
    await sessao.entrar(sessaoDeTeste);
  });

  test('põe o Bearer da sessão em toda requisição', () async {
    montar(apiHandler: (_) async => respostaJson(200, {}));
    await dio.get('empresa/config/');
    expect(
      api.requisicoes.single.headers['Authorization'],
      'Bearer ${sessaoDeTeste.access}',
    );
  });

  test('rotas de auth vão sem token', () async {
    montar(apiHandler: (_) async => respostaJson(200, {}));
    await dio.post('auth/logout/', data: {'refresh': 'x'});
    expect(api.requisicoes.single.headers['Authorization'], isNull);
  });

  test('401 token_invalido renova uma vez e repete a requisição', () async {
    montar();
    final response = await dio.get('empresa/config/');

    expect(response.data, {'ok': true});
    expect(renovacao.requisicoes.length, 1);
    expect(renovacao.requisicoes.single.data, {
      'refresh': sessaoDeTeste.refresh,
    });
    expect(renovacao.requisicoes.single.headers['Authorization'], isNull);
    expect(api.requisicoes.length, 2);
    expect(
      api.requisicoes.last.headers['Authorization'],
      'Bearer ${sessaoRenovada.access}',
    );
    expect(sessao.atual, sessaoRenovada);
  });

  test(
    'várias requisições com 401 ao mesmo tempo renovam só uma vez',
    () async {
      montar();
      final respostas = await Future.wait([
        dio.get('agendamentos/'),
        dio.get('clientes/'),
        dio.get('servicos/'),
      ]);

      expect(respostas.map((r) => r.statusCode), everyElement(200));
      expect(renovacao.requisicoes.length, 1);
      expect(sessao.atual, sessaoRenovada);
    },
  );

  test('se o refresh for recusado, a sessão acaba e o erro sobe', () async {
    montar(
      renovacaoHandler: (_) async =>
          respostaErro(401, 'token_invalido', detail: 'Refresh já usado.'),
    );

    await expectLater(
      dio.get('empresa/config/'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    expect(sessao.autenticado, isFalse);
    expect(api.requisicoes.length, 1);
  });

  test('se o refresh cair por rede, a sessão continua valendo', () async {
    montar(
      renovacaoHandler: (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      ),
    );

    await expectLater(dio.get('empresa/config/'), throwsA(isA<DioException>()));
    expect(sessao.atual, sessaoDeTeste);
  });

  test('401 que não é token expirado encerra a sessão sem renovar', () async {
    montar(
      apiHandler: (_) async => respostaErro(
        401,
        'inactivity_timeout',
        detail: 'Sessão expirada por inatividade.',
      ),
    );

    await expectLater(dio.get('empresa/config/'), throwsA(isA<DioException>()));
    expect(renovacao.requisicoes, isEmpty);
    expect(sessao.autenticado, isFalse);
  });

  test('401 numa rota de auth é erro da tela, não sessão expirada', () async {
    montar(
      apiHandler: (_) async => respostaErro(
        401,
        'credenciais_invalidas',
        detail: 'E-mail ou senha inválidos.',
      ),
    );

    await expectLater(
      dio.post('auth/login/', data: {'email': 'a@b.c', 'senha': 'x'}),
      throwsA(isA<DioException>()),
    );
    expect(renovacao.requisicoes, isEmpty);
    expect(sessao.atual, sessaoDeTeste);
  });

  test('se a repetição também der 401, não renova de novo', () async {
    montar(apiHandler: (_) async => respostaErro(401, 'token_invalido'));

    await expectLater(dio.get('empresa/config/'), throwsA(isA<DioException>()));
    expect(renovacao.requisicoes.length, 1);
    expect(api.requisicoes.length, 2);
    expect(sessao.autenticado, isFalse);
  });

  test('sem sessão, o 401 passa direto', () async {
    await sessao.sair();
    montar(apiHandler: (_) async => respostaErro(401, 'nao_autenticado'));

    await expectLater(dio.get('empresa/config/'), throwsA(isA<DioException>()));
    expect(renovacao.requisicoes, isEmpty);
  });
}
