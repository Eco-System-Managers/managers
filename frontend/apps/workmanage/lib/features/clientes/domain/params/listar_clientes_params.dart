// a página pedida (a partir de 1) e a busca, que a API aplica em nome,
// telefone, e-mail e CPF
class ListarClientesParams {
  const ListarClientesParams({this.pagina = 1, this.busca});

  final int pagina;
  final String? busca;
}
