// os filtros da lista: busca em nome e descrição, e ativo (true só os
// ativos, false só os inativos, null todos)
class ListarServicosParams {
  const ListarServicosParams({this.busca, this.ativo});

  final String? busca;
  final bool? ativo;
}
