import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:managers/core/theme/brand.dart';

import '../../domain/entities/empresa_config.dart';
import '../../empresa_provider.dart';
import '../widgets/nicho_visual.dart';

// o menu das configurações: a logo no topo, as seções editáveis e o que é
// só leitura (o modo de agenda, que a API não deixa trocar depois do
// onboarding; os nichos mudam só dentro da área dele). só o proprietário
// troca a logo e entra nas seções
class ConfiguracoesPage extends ConsumerWidget {
  const ConfiguracoesPage({super.key});

  Future<void> _trocarLogo(BuildContext context, WidgetRef ref) async {
    // a galeria é coisa de tela: o provider recebe só os bytes
    final imagem = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (imagem == null) return;
    final bytes = await imagem.readAsBytes();
    if (!context.mounted) return;
    await ref.read(configuracoesProvider).enviarLogo(bytes, imagem.name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final configuracoes = ref.watch(configuracoesProvider);
    final negocio = ref.watch(negocioAtualProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListenableBuilder(
        listenable: Listenable.merge([configuracoes, negocio]),
        builder: (context, _) {
          final config = negocio.config ?? const EmpresaConfig();
          final proprietario = negocio.ehProprietario;

          return ListView(
            children: [
              _Logo(
                url: config.logoUrl,
                nome: config.nome,
                enviando: configuracoes.enviandoLogo,
                erro: configuracoes.errorMessage,
                onTrocar: proprietario && !configuracoes.enviandoLogo
                    ? () => _trocarLogo(context, ref)
                    : null,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.business_rounded),
                title: const Text('Dados do negócio'),
                subtitle: const Text('Nome, telefone, documento e endereço'),
                trailing: const Icon(Icons.chevron_right_rounded),
                enabled: proprietario,
                onTap: () => context.push('/mais/configuracoes/negocio'),
              ),
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Horários'),
                subtitle: const Text('Dias e horários de funcionamento'),
                trailing: const Icon(Icons.chevron_right_rounded),
                enabled: proprietario,
                onTap: () => context.push('/mais/configuracoes/horarios'),
              ),
              if (config.tipoAgenda == TipoAgenda.kanban)
                ListTile(
                  leading: const Icon(Icons.view_kanban_rounded),
                  title: const Text('Etapas do quadro'),
                  subtitle: const Text('As colunas da esteira e a ordem delas'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  enabled: proprietario,
                  onTap: () => context.push('/mais/etapas'),
                ),
              // os nichos mudam dentro da área; o outro não tem área para
              // trocar, então fica só leitura
              ListTile(
                leading: const Icon(Icons.storefront_rounded),
                title: const Text('Nichos'),
                subtitle: Text(_nomeDosNichos(config)),
                trailing: config.ehOutro
                    ? null
                    : const Icon(Icons.chevron_right_rounded),
                enabled: proprietario && !config.ehOutro,
                onTap: () => context.push('/mais/configuracoes/nichos'),
              ),
              const Divider(),
              // o que foi definido no onboarding e a API não deixa trocar:
              // mostrar como editável só geraria o erro modo_agenda_bloqueado
              ListTile(
                leading: const Icon(Icons.view_agenda_rounded),
                title: const Text('Modo de agenda'),
                subtitle: Text(
                  config.tipoAgenda == TipoAgenda.kanban
                      ? 'Esteira: o cliente deixa e busca depois'
                      : 'Horário marcado',
                ),
              ),
              if (!proprietario)
                Padding(
                  padding: const EdgeInsets.all(BrandSpacing.space4),
                  child: Text(
                    'Só o proprietário altera as configurações.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: BrandColors.of(context).inkMuted),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _nomeDosNichos(EmpresaConfig config) {
    if (config.nichos.isEmpty) return 'Não informado';
    return nomeDosNichos(config.nichos, descricao: config.nichoDescricao);
  }
}

class _Logo extends StatelessWidget {
  const _Logo({
    required this.url,
    required this.nome,
    required this.enviando,
    required this.erro,
    required this.onTrocar,
  });

  final String url;
  final String nome;
  final bool enviando;
  final String? erro;
  final VoidCallback? onTrocar;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(BrandSpacing.space5),
      child: Column(
        children: [
          // a área do logo é o fundo 2, com o ícone neutro enquanto o
          // negócio não tem logo
          CircleAvatar(
            radius: 48,
            backgroundColor: cores.bg2,
            foregroundImage: url.isNotEmpty ? NetworkImage(url) : null,
            child: enviando
                ? const CircularProgressIndicator()
                : Icon(
                    Icons.storefront_rounded,
                    size: 40,
                    color: cores.inkMuted,
                  ),
          ),
          const SizedBox(height: BrandSpacing.space3),
          // o nome do negócio é o título da tela: h2, como nas fichas
          Text(
            nome,
            textAlign: TextAlign.center,
            style: BrandText.h2.copyWith(color: cores.ink),
          ),
          if (onTrocar != null || enviando) ...[
            const SizedBox(height: BrandSpacing.space2),
            TextButton.icon(
              onPressed: onTrocar,
              icon: const Icon(Icons.photo_rounded),
              label: Text(url.isEmpty ? 'Adicionar logo' : 'Trocar logo'),
            ),
          ],
          if (erro != null)
            Padding(
              padding: const EdgeInsets.only(top: BrandSpacing.space2),
              child: Text(
                erro!,
                textAlign: TextAlign.center,
                style: textos.bodyMedium?.copyWith(color: colors.error),
              ),
            ),
        ],
      ),
    );
  }
}
