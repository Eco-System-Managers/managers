// o tema que a pessoa escolheu no Mais. vale só neste aparelho;
// sem escolha, o app segue o claro ou o escuro do aparelho
enum PreferenciaDeTema {
  sistema('Igual ao aparelho'),
  claro('Claro'),
  escuro('Escuro');

  const PreferenciaDeTema(this.nome);

  final String nome;
}
