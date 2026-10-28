import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand_logo.dart';

// as telas de abertura (splash, entrar, cadastro, recuperar senha) ficam
// fora do app: o marinho da marca nos dois temas, com a barra de status clara
const estiloDaBarraDeAbertura = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

// logo branco das telas de auth, centralizado na área acima do painel.
// encolhe junto com essa área (ex.: quando o teclado abre): o empilhado vira
// só o símbolo quando a wordmark ficaria pequena, e some quando nem o símbolo
// cabe. showName = false mostra só o símbolo
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key, this.showName = true});

  final bool showName;

  // a altura de referência do Design System para o logo (a 96 px, o respiro
  // é space-5)
  static const _alturaMaxima = 96.0;

  // abaixo disto a wordmark do empilhado fica miúda: vai só o símbolo
  static const _alturaMinimaDoEmpilhado = 72.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, area) {
        double alturaPara(FormaDoLogo forma) =>
            BrandLogo.alturaQueCabe(forma, area).clamp(0.0, _alturaMaxima);

        var forma = showName ? FormaDoLogo.empilhado : FormaDoLogo.simbolo;
        var altura = alturaPara(forma);
        if (forma == FormaDoLogo.empilhado &&
            altura < _alturaMinimaDoEmpilhado) {
          forma = FormaDoLogo.simbolo;
          altura = alturaPara(forma);
        }
        if (altura < BrandLogo.alturaMinimaDoSimbolo) {
          return const SizedBox.shrink();
        }
        return Center(
          child: BrandLogo(forma: forma, cor: CorDoLogo.branco, altura: altura),
        );
      },
    );
  }
}
