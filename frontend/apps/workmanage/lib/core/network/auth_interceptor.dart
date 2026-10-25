import 'package:dio/dio.dart';

import '../error/api_erro.dart';
import '../session/bloqueio_assinatura.dart';
import '../session/sessao.dart';
import '../session/sessao_controller.dart';
import '../session/sessao_model.dart';

// põe o token em toda requisição e renova a sessão quando o access expira.
// as regras vêm do backend (core/excecoes.py e autenticacao/CLAUDE.md):
// - access expirado é 401 com code token_invalido: renova uma vez e repete
// - qualquer outro 401 numa rota autenticada (inactivity_timeout,
//   conta_inativa, sessao_encerrada, tenant_invalido, nao_autenticado)
//   significa que a sessão acabou: limpa, e o router leva ao login
// - as rotas de auth ficam de fora: o 401 do login é "e-mail ou senha
//   inválidos", não sessão expirada, e refresh e logout vão sem token
// - 402 (assinatura_bloqueada) em qualquer rota marca o bloqueio: o router
//   leva à tela de assinatura, e o erro segue para a tela que chamou
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._sessao,
    required this._dio,
    required this._dioRenovacao,
    this._bloqueio,
  });

  final SessaoController _sessao;
  final BloqueioAssinatura? _bloqueio;

  // o Dio do app, para repetir a requisição que falhou
  final Dio _dio;

  // um Dio sem este interceptor: o refresh não pode tentar se renovar
  final Dio _dioRenovacao;

  static const _prefixoAuth = 'auth/';
  static const _codigoRenovavel = 'token_invalido';
  static const _marcaRepetida = 'sessaoRenovada';

  // a renovação em andamento. quem chegar com 401 enquanto ela roda espera
  // a mesma, porque cada refresh vale uma vez: dois em paralelo derrubariam
  // a sessão
  Future<Sessao?>? _renovacao;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final sessao = _sessao.atual;
    if (sessao != null && !_rotaDeAuth(options)) {
      options.headers['Authorization'] = _bearer(sessao);
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    if (response?.statusCode == 402) {
      final detail = ApiErro.fromJson(response!.data)?.detail;
      _bloqueio?.marcar(
        detail ?? 'Assinatura inativa. Assine um plano para continuar.',
      );
      handler.next(err);
      return;
    }

    final sessao = _sessao.atual;
    if (response?.statusCode != 401 ||
        sessao == null ||
        _rotaDeAuth(err.requestOptions)) {
      handler.next(err);
      return;
    }

    final code = ApiErro.fromJson(response!.data)?.code;
    final jaRepetiu = err.requestOptions.extra[_marcaRepetida] == true;
    if (code != _codigoRenovavel || jaRepetiu) {
      await _sessao.sair();
      handler.next(err);
      return;
    }

    // se a requisição saiu com um token que já foi trocado (outra renovação
    // terminou enquanto ela viajava), basta repetir com o atual
    final usado = err.requestOptions.headers['Authorization'];
    final nova = usado != _bearer(sessao) ? sessao : await _renovar();
    if (nova == null) {
      handler.next(err);
      return;
    }

    final opcoes = err.requestOptions
      ..headers['Authorization'] = _bearer(nova)
      ..extra[_marcaRepetida] = true;
    try {
      handler.resolve(await _dio.fetch(opcoes));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<Sessao?> _renovar() {
    return _renovacao ??= _executarRenovacao().whenComplete(
      () => _renovacao = null,
    );
  }

  Future<Sessao?> _executarRenovacao() async {
    final atual = _sessao.atual;
    if (atual == null) return null;
    try {
      final response = await _dioRenovacao.post<Map<String, dynamic>>(
        'auth/token-refresh/',
        data: {'refresh': atual.refresh},
      );
      final nova = SessaoModel.fromJson(response.data!).toEntity();
      await _sessao.renovar(nova);
      return nova;
    } on DioException catch (e) {
      // com resposta, a API recusou o refresh (reusado, revogado, conta
      // inativa): a sessão acabou. sem resposta é rede: ela continua valendo
      if (e.response != null) await _sessao.sair();
      return null;
    }
  }

  bool _rotaDeAuth(RequestOptions options) =>
      options.path.startsWith(_prefixoAuth);

  String _bearer(Sessao sessao) => 'Bearer ${sessao.access}';
}
