import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/avatar_iniciais.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/features/empresa/empresa_provider.dart';

import '../../domain/entities/colaborador.dart';
import '../../domain/entities/convite.dart';
import '../../usuarios_provider.dart';
import '../providers/equipe_provider.dart';

// a equipe do negócio e os convites pendentes. só o proprietário adiciona,
// convida, cancela convite e mexe na ficha; o resto da equipe só vê
class EquipePage extends ConsumerStatefulWidget {
  const EquipePage({super.key});

  @override
  ConsumerState<EquipePage> createState() => _EquipePageState();
}

class _EquipePageState extends ConsumerState<EquipePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(equipeProvider).carregar();
    });
  }

  // ficha e convite podem ter mudado a equipe: ela vem da API de novo
  Future<void> _abrir(String rota) async {
    await context.push(rota);
    if (mounted) ref.read(equipeProvider).carregar();
  }

  // duas portas de entrada: cadastrar sem login (já aparece nos filtros)
  // ou convidar por e-mail (a pessoa cria a senha e entra)
  Future<void> _adicionar() async {
    final rota = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Adicionar à equipe'),
              subtitle: const Text(
                'Sem login. Aparece na agenda e nos filtros na hora.',
              ),
              onTap: () => Navigator.of(context).pop('/mais/equipe/novo'),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Convidar por e-mail'),
              subtitle: const Text('A pessoa cria a senha e entra no app.'),
              onTap: () => Navigator.of(context).pop('/mais/equipe/convidar'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (rota != null && mounted) await _abrir(rota);
  }

  Future<void> _cancelarConvite(Convite convite) async {
    final ok = await confirmar(
      context,
      titulo: 'Cancelar convite',
      mensagem: 'O link enviado para ${convite.email} deixa de funcionar.',
      textoConfirmar: 'Cancelar convite',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    await ref.read(equipeProvider).cancelarConvite(convite.id);
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(equipeProvider);
    final negocio = ref.watch(negocioAtualProvider);

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Equipe')),
          floatingActionButton: negocio.ehProprietario
              ? FloatingActionButton.extended(
                  onPressed: _adicionar,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Adicionar'),
                )
              : null,
          body: _corpo(provider, negocio.perfil?.id),
        );
      },
    );
  }

  Widget _corpo(EquipeProvider provider, int? meuId) {
    if (!provider.carregado) {
      final erro = provider.erroAoCarregar;
      if (erro != null) {
        return EstadoErro(
          mensagem: erro.message,
          onTentarDeNovo: provider.carregar,
        );
      }
      return const Carregando();
    }

    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: provider.carregar,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          if (provider.isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
          if (provider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                provider.errorMessage!,
                style: TextStyle(color: colors.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Equipe (${provider.colaboradores.length})',
              style: textos.titleSmall,
            ),
          ),
          for (final c in provider.colaboradores)
            _ColaboradorTile(
              colaborador: c,
              souEu: c.id == meuId,
              onTap: () => _abrir('/mais/equipe/${c.id}'),
            ),

          if (provider.convites.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
              child: Text(
                'Convites pendentes (${provider.convites.length})',
                style: textos.titleSmall,
              ),
            ),
            for (final convite in provider.convites)
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: Text(convite.email),
                subtitle: Text(
                  [
                    if (convite.nome.isNotEmpty) convite.nome,
                    'expira em ${formatarData(convite.expiraEm)}',
                  ].join(' · '),
                ),
                trailing: IconButton(
                  tooltip: 'Cancelar convite',
                  icon: const Icon(Icons.close),
                  onPressed: provider.isLoading
                      ? null
                      : () => _cancelarConvite(convite),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ColaboradorTile extends StatelessWidget {
  const _ColaboradorTile({
    required this.colaborador,
    required this.souEu,
    required this.onTap,
  });

  final Colaborador colaborador;
  final bool souEu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final c = colaborador;

    return ListTile(
      enabled: c.ativo,
      leading: AvatarIniciais(nome: c.nome),
      title: Text(souEu ? '${c.nome} (você)' : c.nome),
      subtitle: Text(
        [
          if (c.funcao.isNotEmpty) c.funcao,
          c.ehProprietario ? 'Proprietário' : c.tipo.nome,
        ].join(' · '),
      ),
      trailing: !c.ativo
          ? Chip(
              label: const Text('Inativo'),
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: colors.outline),
            )
          : c.ehProprietario
          ? Chip(
              label: const Text('Dono'),
              visualDensity: VisualDensity.compact,
              backgroundColor: colors.secondaryContainer,
            )
          : !c.temAcesso
          ? Chip(
              label: const Text('Sem acesso'),
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: colors.outline),
            )
          : const Icon(Icons.chevron_right),
      // inativo continua abrindo: é lá que se reativa
      onTap: onTap,
    );
  }
}
