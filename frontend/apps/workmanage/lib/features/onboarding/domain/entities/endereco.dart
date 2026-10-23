// o que a busca por CEP devolve. o número não vem: quem informa é o usuário
class Endereco {
  const Endereco({
    required this.cep,
    required this.endereco,
    required this.cidade,
    required this.uf,
  });

  final String cep;
  final String endereco;
  final String cidade;
  final String uf;
}
