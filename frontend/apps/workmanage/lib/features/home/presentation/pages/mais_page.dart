import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/features/empresa/empresa_provider.dart';

import '../../home_provider.dart';

// a aba "Mais": configurações, serviços, financeiro, contratos, equipe,
// assinatura e sair
class MaisPage extends ConsumerWidget {
  const MaisPage({super.key});

  Future<void> _sair(BuildContext context, WidgetRef ref) async {
    final ok = await confirmar(
      context,
      titulo: 'Sair',
      mensagem: 'Você vai precisar entrar de novo com e-mail e senha.',
      textoConfirmar: 'Sair',
    );
    if (!ok || !context.mounted) return;
    await ref.read(maisProvider).sair();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch: mantém o provider vivo enquanto a aba estiver aberta
    final mais = ref.watch(maisProvider);
    final negocio = ref.watch(negocioAtualProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListenableBuilder(
        listenable: Listenable.merge([mais, negocio]),
        builder: (context, _) {
          return ListView(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  foregroundImage: negocio.logoUrl.isNotEmpty
                      ? NetworkImage(negocio.logoUrl)
                      : null,
                  child: Icon(
                    Icons.storefront_outlined,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                title: Text(negocio.nome),
                subtitle: Text(
                  negocio.ehProprietario ? 'Proprietário' : 'Colaborador',
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Configurações'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/mais/configuracoes'),
              ),
              ListTile(
                leading: const Icon(Icons.design_services_outlined),
                title: const Text('Serviços'),
                subtitle: const Text(
                  'O catálogo: o que você vende e por quanto',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/mais/servicos'),
              ),
              // o colaborador comum não vê dinheiro (a API também nega)
              if (negocio.veValores)
                ListTile(
                  leading: const Icon(Icons.point_of_sale_outlined),
                  title: const Text('Financeiro'),
                  subtitle: const Text('O caixa: o fechamento por período'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/mais/financeiro'),
                ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Contratos'),
                subtitle: const Text('Modelos, contratos gerados e o PDF'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/mais/contratos'),
              ),
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('Equipe'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/mais/equipe'),
              ),
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Assinatura'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/mais/assinatura'),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: colors.error),
                title: Text('Sair', style: TextStyle(color: colors.error)),
                enabled: !mais.saindo,
                onTap: () => _sair(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }
}
