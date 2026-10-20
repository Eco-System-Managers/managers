import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// logo branco das telas de auth, centralizado na área acima do painel.
// encolhe junto com essa área (ex.: quando o teclado abre).
// showName = false mostra só o símbolo, sem o texto "Work Manage"
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key, this.showName = true});

  final bool showName;

  static const _fullAsset =
      'assets/images/work-manage-logo-principal-branco.svg';
  static const _symbolAsset = 'assets/images/work-manage-simbolo-branco.svg';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: SvgPicture.asset(
          showName ? _fullAsset : _symbolAsset,
          fit: BoxFit.contain,
          semanticsLabel: 'Work Manage',
        ),
      ),
    );
  }
}
