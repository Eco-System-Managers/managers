import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/colaborador.dart';
import '../../usuarios_provider.dart';
import '../widgets/campos_colaborador.dart';

// cadastra alguém da equipe sem login: já aparece nos filtros e na agenda.
// para dar acesso ao app, a ficha tem "convidar". fecha com true quando criou
class ColaboradorFormPage extends ConsumerStatefulWidget {
  const ColaboradorFormPage({super.key});

  @override
  ConsumerState<ColaboradorFormPage> createState() =>
      _ColaboradorFormPageState();
}

class _ColaboradorFormPageState extends ConsumerState<ColaboradorFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _funcaoController = TextEditingController();
  final _comissaoController = TextEditingController();
  VinculoColaborador _tipo = VinculoColaborador.parceiro;
  bool _podeCobrar = true;

  @override
  void dispose() {
    _nomeController.dispose();
    _funcaoController.dispose();
    _comissaoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(colaboradorFormProvider)
        .salvar(
          CamposColaborador.dados(
            nome: _nomeController,
            funcao: _funcaoController,
            comissao: _comissaoController,
            tipo: _tipo,
            podeCobrar: _podeCobrar,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(colaboradorFormProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar à equipe')),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          if (provider.salvo) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.pop(true);
            });
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'A pessoa passa a aparecer na agenda, no quadro e nos '
                  'filtros. Para ela entrar no app, convide pela ficha.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                if (provider.errorMessage != null) ...[
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
                  const SizedBox(height: 16),
                ],
                CamposColaborador(
                  nomeController: _nomeController,
                  funcaoController: _funcaoController,
                  comissaoController: _comissaoController,
                  tipo: _tipo,
                  podeCobrar: _podeCobrar,
                  onTipo: (t) => setState(() => _tipo = t),
                  onPodeCobrar: (v) => setState(() => _podeCobrar = v),
                  erroDoCampo: provider.erroDoCampo,
                  limparErroDoCampo: provider.limparErroDoCampo,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: provider.isLoading ? null : _salvar,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Adicionar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
