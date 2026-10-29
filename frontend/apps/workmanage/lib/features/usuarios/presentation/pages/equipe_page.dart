import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/avatar_iniciais.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/selo_de_status.dart';
import 'package:managers/features/empresa/empresa_provider.dart';

import '../../domain/entities/colaborador.dart';
import '../../domain/entities/convite.dart';
import '../../usuarios_provider.dart';
import '../providers/equipe_provider.dart';

// a equipe do negócio, com o convite pendente de cada um na linha. só o
// proprietário adiciona, cancela convite e mexe na ficha; o resto só vê
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

  Future<void> _cancelarConvite(Convite convite) async {
    final ok = await confirmar(
      context,
      titulo: 'Cancelar convite',
      mensagem: 'O link enviado para ${convite.email} deixa de funcionar.',
      textoConfirmar: 'Cancelar convite',
      textoCancelar: 'Voltar',
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
                  onPressed: () => _abrir('/mais/equipe/novo'),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
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
        // folga para o botão flutuante não cobrir o fim da lista
        padding: const EdgeInsets.only(bottom: BrandSpacing.space7),
        children: [
          if (provider.isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
          if (provider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BrandSpacing.space4,
                BrandSpacing.space2,
                BrandSpacing.space4,
                0,
              ),
              child: Text(
                provider.errorMessage!,
                style: textos.bodyMedium?.copyWith(color: colors.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BrandSpacing.space4,
              BrandSpacing.space4,
              BrandSpacing.space4,
              BrandSpacing.space1,
            ),
            child: Text(
              'Equipe (${provider.colaboradores.length})',
              style: textos.titleSmall,
            ),
          ),
          for (final c in provider.colaboradores)
            _ColaboradorTile(
              colaborador: c,
              souEu: c.id == meuId,
              conviteEnviado: provider.conviteDe(c.id) != null,
              onTap: () => _abrir('/mais/equipe/${c.id}'),
            ),

          if (provider.convitesSoltos.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BrandSpacing.space4,
                BrandSpacing.space5,
                BrandSpacing.space4,
                BrandSpacing.space1,
              ),
              child: Text(
                'Convites pendentes (${provider.convitesSoltos.length})',
                style: textos.titleSmall,
              ),
            ),
            for (final convite in provider.convitesSoltos)
              ListTile(
                leading: const Icon(Icons.mail_outline_rounded),
                title: Text(convite.email),
                subtitle: Text(
                  [
                    if (convite.nome.isNotEmpty) convite.nome,
                    'expira em ${formatarData(convite.expiraEm)}',
                  ].join(' · '),
                ),
                trailing: IconButton(
                  tooltip: 'Cancelar convite',
                  icon: const Icon(Icons.close_rounded),
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
    required this.conviteEnviado,
    required this.onTap,
  });

  final Colaborador colaborador;
  final bool souEu;

  // sem login ainda, mas com o convite a caminho
  final bool conviteEnviado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final c = colaborador;

    return ListTile(
      leading: AvatarIniciais(nome: c.nome),
      // quem está inativo vai em inkMuted, e a linha continua tocável: é na
      // ficha que se reativa
      titleTextStyle: c.ativo
          ? null
          : textos.titleMedium?.copyWith(color: cores.inkMuted),
      title: Text(souEu ? '${c.nome} (você)' : c.nome),
      subtitle: Text(
        [
          if (c.funcao.isNotEmpty) c.funcao,
          c.ehProprietario ? 'Proprietário' : c.tipo.nome,
        ].join(' · '),
      ),
      // o convite a caminho é pendente (warning); inativo e sem acesso são
      // neutros; o dono leva o selo em azul suave
      trailing: !c.ativo
          ? SeloDeStatus(texto: 'Inativo', cor: cores.inkMuted)
          : c.ehProprietario
          ? Chip(
              label: const Text('Dono'),
              visualDensity: VisualDensity.compact,
              backgroundColor: cores.blueSoft,
              side: BorderSide.none,
            )
          : !c.temAcesso && conviteEnviado
          ? SeloDeStatus(
              texto: 'Convite enviado',
              icone: Icons.mail_outline_rounded,
              cor: cores.warning,
            )
          : !c.temAcesso
          ? SeloDeStatus(texto: 'Sem acesso', cor: cores.inkMuted)
          : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
