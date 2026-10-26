import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:validatorless/validatorless.dart';

import '../../domain/entities/colaborador.dart';
import '../../usuarios_provider.dart';
import '../widgets/campos_colaborador.dart';

// adiciona alguém à equipe num passo só: nome, função, vínculo (com a
// comissão ou a permissão de cobrar) e, ligando o acesso ao app, o e-mail do
// convite. a pessoa já aparece na agenda e nos filtros; com e-mail, recebe o
// link para criar a senha. fecha com true quando terminou
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
  final _emailController = TextEditingController();
  VinculoColaborador _tipo = VinculoColaborador.parceiro;
  bool _podeCobrar = true;
  bool _convidar = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _funcaoController.dispose();
    _comissaoController.dispose();
    _emailController.dispose();
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
          email: _convidar ? _emailController.text : '',
        );
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(colaboradorFormProvider);
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

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
          // a pessoa já foi criada: os dados dela não vão de novo, só o
          // convite
          final soConvite = provider.criadoSemConvite;

          return Form(
            key: _formKey,
            child: ListView(
              padding: paddingDaPagina(context),
              children: [
                Text(
                  'A pessoa passa a aparecer na agenda, no quadro e nos '
                  'filtros na hora.',
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
                      soConvite
                          ? '${provider.criado!.nome} já está na equipe, mas '
                                'o convite não saiu: ${provider.errorMessage}'
                          : provider.errorMessage!,
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
                  habilitado: !soConvite,
                  // com convite a caminho a pessoa vai entrar no app
                  temAcesso: _convidar,
                ),

                const SizedBox(height: 24),
                Text('Acesso ao app', style: textos.titleSmall),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Convidar para entrar no app'),
                  subtitle: const Text(
                    'A pessoa recebe um link por e-mail para criar a senha. '
                    'Dá para mandar o mesmo link por WhatsApp pela ficha.',
                  ),
                  value: _convidar,
                  onChanged: (v) => setState(() => _convidar = v),
                ),
                if (_convidar) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _salvar(),
                    validator: Validatorless.multiple([
                      Validatorless.required('Informe o e-mail'),
                      Validatorless.email('E-mail inválido'),
                    ]),
                    forceErrorText: provider.erroDoCampo('email'),
                    onChanged: (_) => provider.limparErroDoCampo('email'),
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      helperText: 'O convite vale por 2 dias.',
                      prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                FilledButton(
                  onPressed: provider.isLoading ? null : _salvar,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    soConvite
                        ? 'Enviar convite'
                        : _convidar
                        ? 'Adicionar e convidar'
                        : 'Adicionar',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
