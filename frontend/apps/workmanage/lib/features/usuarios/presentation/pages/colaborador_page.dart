import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/widgets/avatar_iniciais.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/features/empresa/empresa_provider.dart';

import '../../domain/entities/colaborador.dart';
import '../../usuarios_provider.dart';
import '../providers/colaborador_provider.dart';

// a ficha de alguém da equipe: a função (editável pelo proprietário),
// desativar/reativar e remover. o proprietário não se desativa nem se
// remove (a API recusa com proprietario_protegido; a tela nem oferece)
class ColaboradorPage extends ConsumerStatefulWidget {
  const ColaboradorPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ColaboradorPage> createState() => _ColaboradorPageState();
}

class _ColaboradorPageState extends ConsumerState<ColaboradorPage> {
  final _funcaoController = TextEditingController();
  bool _preenchido = false;

  ColaboradorProvider get _provider => ref.read(colaboradorProvider(widget.id));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  @override
  void dispose() {
    _funcaoController.dispose();
    super.dispose();
  }

  Future<void> _alterarAtivo(Colaborador c) async {
    final ativar = !c.ativo;
    final ok = await confirmar(
      context,
      titulo: ativar ? 'Reativar' : 'Desativar',
      mensagem: ativar
          ? '${c.nome} volta a entrar no app e a aparecer na agenda.'
          : '${c.nome} perde o acesso na hora e sai dos serviços que '
                'executa. Os agendamentos já marcados continuam.',
      textoConfirmar: ativar ? 'Reativar' : 'Desativar',
      destrutivo: !ativar,
    );
    if (!ok || !mounted) return;
    await _provider.alterarAtivo(ativar);
  }

  Future<void> _remover(Colaborador c) async {
    final pendentes = await _provider.contarPendentes();
    if (pendentes == null || !mounted) return;
    final aviso = pendentes == 0
        ? ''
        : pendentes == 1
        ? ' Um agendamento futuro fica sem profissional.'
        : ' $pendentes agendamentos futuros ficam sem profissional.';
    final ok = await confirmar(
      context,
      titulo: 'Remover da equipe',
      mensagem:
          'A conta de ${c.nome} é apagada e o acesso termina na hora.$aviso',
      textoConfirmar: 'Remover',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    await _provider.remover();
  }

  Future<void> _salvarFuncao() async {
    await _provider.salvarFuncao(_funcaoController.text);
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(colaboradorProvider(widget.id));
    final negocio = ref.watch(negocioAtualProvider);

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        if (provider.removido) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop(true);
          });
        }
        if (provider.funcaoSalva) {
          provider.avisoDeFuncaoMostrado();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Função salva.')));
            }
          });
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Colaborador')),
          body: _corpo(provider, negocio.ehProprietario),
        );
      },
    );
  }

  Widget _corpo(ColaboradorProvider provider, bool souProprietario) {
    final c = provider.colaborador;
    if (c == null) {
      final erro = provider.erroAoCarregar;
      if (erro != null) {
        return EstadoErro(
          mensagem: erro.message,
          onTentarDeNovo: provider.carregar,
        );
      }
      return const Carregando();
    }

    if (!_preenchido) {
      _funcaoController.text = c.funcao;
      _preenchido = true;
    }

    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    // o dono não se desativa nem se remove; quem não é dono não mexe em nada
    final podeMexer = souProprietario && !c.ehProprietario;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (provider.isLoading)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        const SizedBox(height: 16),
        Center(child: AvatarIniciais(nome: c.nome, raio: 40)),
        const SizedBox(height: 12),
        Text(
          c.nome,
          textAlign: TextAlign.center,
          style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          c.email,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            Chip(
              label: Text(c.ehProprietario ? 'Proprietário' : 'Colaborador'),
              visualDensity: VisualDensity.compact,
            ),
            Chip(
              avatar: Icon(
                c.ativo ? Icons.check_circle_outline : Icons.block,
                size: 18,
                color: c.ativo ? Colors.green.shade700 : colors.error,
              ),
              label: Text(c.ativo ? 'Ativo' : 'Inativo'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),

        if (provider.errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              provider.errorMessage!,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],

        const SizedBox(height: 24),
        TextFormField(
          controller: _funcaoController,
          enabled: souProprietario,
          textCapitalization: TextCapitalization.sentences,
          forceErrorText: provider.erroDoCampo('funcao'),
          onChanged: (_) => provider.limparErroDoCampo('funcao'),
          decoration: const InputDecoration(
            labelText: 'Função',
            hintText: 'Ex.: Barbeiro',
            border: OutlineInputBorder(),
          ),
        ),
        if (souProprietario) ...[
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: provider.isLoading ? null : _salvarFuncao,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Salvar função'),
          ),
        ],

        if (podeMexer) ...[
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: provider.isLoading ? null : () => _alterarAtivo(c),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: c.ativo ? colors.error : null,
            ),
            icon: Icon(c.ativo ? Icons.block : Icons.check_circle_outline),
            label: Text(c.ativo ? 'Desativar' : 'Reativar'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: provider.isLoading ? null : () => _remover(c),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('Remover da equipe'),
          ),
        ],
      ],
    );
  }
}
