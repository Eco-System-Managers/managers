// uma página de uma lista da API, já no domínio: os itens, o total e se
// existe próxima página. o repository monta isto a partir da Pagina do
// network, para o domain não conhecer URL de próxima página
class ListaPaginada<T> {
  const ListaPaginada({
    required this.itens,
    required this.total,
    required this.temMais,
  });

  final List<T> itens;
  final int total;
  final bool temMais;
}
