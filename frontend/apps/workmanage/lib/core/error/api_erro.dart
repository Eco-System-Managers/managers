// o corpo de erro da API: {detail, code, fields?} (backend/openapi/README.md).
// detail é a mensagem pronta para o usuário; code é o identificador estável
// pelo qual a tela decide o fluxo; fields só vem em erro de validação
class ApiErro {
  const ApiErro({
    required this.detail,
    required this.code,
    this.fields = const {},
  });

  final String detail;
  final String code;
  final Map<String, List<String>> fields;

  // null quando a resposta não segue o contrato (proxy no meio, HTML de erro)
  static ApiErro? fromJson(Object? data) {
    if (data is! Map) return null;
    final detail = data['detail'];
    final code = data['code'];
    if (detail is! String || code is! String) return null;

    final fields = <String, List<String>>{};
    final brutos = data['fields'];
    if (brutos is Map) {
      brutos.forEach((campo, mensagens) {
        fields['$campo'] = mensagens is List
            ? [for (final m in mensagens) '$m']
            : ['$mensagens'];
      });
    }

    return ApiErro(detail: detail, code: code, fields: fields);
  }
}
