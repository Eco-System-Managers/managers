import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/config/env.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/sombra_de_borda.dart';
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../home_provider.dart';

// a aba "Mais": configurações, serviços, financeiro, contratos, equipe,
// assinatura, a política de privacidade, sair e excluir a conta
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
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: comSombraEmBaixo(
        ListenableBuilder(
          listenable: Listenable.merge([mais, negocio]),
          builder: (context, _) {
            return ListView(
              children: [
                ListTile(
                  // a área do logo é o fundo 2, com o ícone neutro enquanto
                  // o negócio não tem logo
                  leading: CircleAvatar(
                    backgroundColor: cores.bg2,
                    foregroundImage: negocio.logoUrl.isNotEmpty
                        ? NetworkImage(negocio.logoUrl)
                        : null,
                    child: Icon(
                      Icons.storefront_rounded,
                      color: cores.inkMuted,
                    ),
                  ),
                  title: Text(negocio.nome),
                  subtitle: Text(
                    negocio.ehProprietario ? 'Proprietário' : 'Colaborador',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_rounded),
                  title: const Text('Configurações'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/mais/configuracoes'),
                ),
                ListTile(
                  leading: const Icon(Icons.design_services_rounded),
                  title: const Text('Serviços'),
                  subtitle: const Text(
                    'O catálogo: o que você vende e por quanto',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/mais/servicos'),
                ),
                // o colaborador comum não vê dinheiro (a API também nega)
                if (negocio.veValores)
                  ListTile(
                    leading: const Icon(Icons.point_of_sale_rounded),
                    title: const Text('Financeiro'),
                    subtitle: const Text('O caixa: o fechamento por período'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/mais/financeiro'),
                  ),
                ListTile(
                  leading: const Icon(Icons.description_rounded),
                  title: const Text('Contratos'),
                  subtitle: const Text('Modelos, contratos gerados e o PDF'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/mais/contratos'),
                ),
                ListTile(
                  leading: const Icon(Icons.group_rounded),
                  title: const Text('Equipe'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/mais/equipe'),
                ),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_rounded),
                  title: const Text('Assinatura'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/mais/assinatura'),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Política de privacidade'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => launchUrl(
                    Uri.parse(Env.linkPrivacidade),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                const Divider(),
                // sair é a ação destrutiva do menu: danger
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: cores.danger),
                  title: Text(
                    'Sair',
                    style: textos.titleMedium?.copyWith(color: cores.danger),
                  ),
                  enabled: !mais.saindo,
                  onTap: () => _sair(context, ref),
                ),
                // as lojas exigem que dê para excluir a conta pelo próprio app
                ListTile(
                  leading: Icon(
                    Icons.person_remove_outlined,
                    color: cores.inkMuted,
                  ),
                  title: Text(
                    'Excluir conta',
                    style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
                  ),
                  onTap: () => context.push('/mais/excluir-conta'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
