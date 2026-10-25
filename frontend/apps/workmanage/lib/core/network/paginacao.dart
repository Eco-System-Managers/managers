import 'package:dio/dio.dart';

// o formato de toda coleção de recurso da API (backend/core/paginacao.py):
// {count, next, previous, results}. page_size vai até 100
class Pagina<T> {
  const Pagina({
    required this.count,
    required this.next,
    required this.previous,
    required this.results,
  });

  final int count;

  // URL absoluta da próxima página; null na última
  final String? next;
  final String? previous;
  final List<T> results;

  factory Pagina.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) item,
  ) {
    return Pagina(
      count: json['count'] as int,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: [
        for (final r in json['results'] as List)
          item(r as Map<String, dynamic>),
      ],
    );
  }
}

const tamanhoMaximoDePagina = 100;

// para as telas que precisam do conjunto inteiro (a agenda e o kanban do
// dia): pede a página maior e segue o next enquanto ele vier. uma página
// que não chega faria horário sumir da tela sem erro nenhum
Future<List<T>> buscarTudo<T>(
  Dio dio,
  String path, {
  Map<String, dynamic>? query,
  required T Function(Map<String, dynamic> json) item,
}) async {
  final primeira = await dio.get<Map<String, dynamic>>(
    path,
    queryParameters: {...?query, 'page_size': tamanhoMaximoDePagina},
  );
  var pagina = Pagina.fromJson(primeira.data!, item);
  final todos = [...pagina.results];

  while (pagina.next != null) {
    // o next já vem com os mesmos filtros e o page_size
    final proxima = await dio.get<Map<String, dynamic>>(pagina.next!);
    pagina = Pagina.fromJson(proxima.data!, item);
    todos.addAll(pagina.results);
  }

  return todos;
}
