// a imagem escolhida na galeria, já em bytes: o domain não conhece arquivo
// nem plugin de imagem
class LogoParams {
  const LogoParams({required this.bytes, required this.nomeArquivo});

  final List<int> bytes;
  final String nomeArquivo;
}
