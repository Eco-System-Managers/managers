import 'package:flutter/material.dart';


class LoginForm extends StatelessWidget {

  const LoginForm({super.key});
  // TODO: Criar atributo do tipo Function chamado callback, inicializar no construtor padrão e chamá-la no onPressed do ElevatedButton

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bem-vindo de volta',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          ElevatedButton(
            onPressed: (){},
            child: Text('Criar conta'),
          )
        ],

      ),
    );
  }
}
