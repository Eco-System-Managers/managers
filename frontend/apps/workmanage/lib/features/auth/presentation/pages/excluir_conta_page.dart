import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:validatorless/validatorless.dart';

import '../../auth_provider.dart';
import '../providers/excluir_conta_provider.dart';

// excluir a própria conta (exigência das lojas e direito da LGPD). o dono
// leva o negócio inteiro; a equipe, só o login. a conta trava na hora e é
// apagada em 30 dias: entrar de novo antes disso desiste. deu certo, a
// sessão acaba e o router leva ao login
class ExcluirContaPage extends ConsumerStatefulWidget {
  const ExcluirContaPage({super.key});

  @override
  ConsumerState<ExcluirContaPage> createState() => _ExcluirContaPageState();
}

class _ExcluirContaPageState extends ConsumerState<ExcluirContaPage> {
  final _formKey = GlobalKey<FormState>();
  final _senhaController = TextEditingController();
  bool _senhaVisivel = false;

  ExcluirContaProvider get _provider => ref.read(excluirContaProvider);

  @override
  void dispose() {
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _excluir(bool ehDono) async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await confirmar(
      context,
      titulo: ehDono ? 'Excluir o negócio?' : 'Excluir sua conta?',
      mensagem: ehDono
          ? 'O negócio e todos os dados dele serão apagados em 30 dias, e '
                'ninguém da equipe entra mais.'
          : 'Seu acesso será apagado em 30 dias.',
      textoConfirmar: 'Excluir',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    await _provider.excluir(_senhaController.text);
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(excluirContaProvider);
    final ehDono = ref.watch(negocioAtualProvider).ehProprietario;
    final colors = Theme.of(context).colorScheme;
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Excluir conta')),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) => Form(
          key: _formKey,
          child: ListView(
            padding: paddingDaPagina(context),
            children: [
              Text(
                ehDono
                    ? 'Como proprietário, excluir a sua conta exclui o negócio '
                          'inteiro: agenda, clientes, serviços, caixa, contratos '
                          'e o acesso de toda a equipe. O negócio também sai do '
                          'app dos clientes.'
                    : 'Excluir a sua conta apaga o seu acesso. Os atendimentos '
                          'que você fez continuam no histórico do negócio, com o '
                          'seu nome.',
                style: textos.bodyLarge,
              ),
              const SizedBox(height: BrandSpacing.space4),
              Container(
                padding: const EdgeInsets.all(BrandSpacing.space3),
                decoration: BoxDecoration(
                  color: cores.blueSoft,
                  borderRadius: BrandRadius.mdAll,
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: cores.ink),
                    const SizedBox(width: BrandSpacing.space3),
                    Expanded(
                      child: Text(
                        'A conta fica travada agora e é apagada de vez em 30 '
                        'dias. Se mudar de ideia, é só entrar de novo antes '
                        'disso.',
                        style: textos.bodyMedium?.copyWith(color: cores.ink),
                      ),
                    ),
                  ],
                ),
              ),
              if (provider.errorMessage != null) ...[
                const SizedBox(height: BrandSpacing.space4),
                Container(
                  padding: const EdgeInsets.all(BrandSpacing.space3),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BrandRadius.mdAll,
                  ),
                  child: Text(
                    provider.errorMessage!,
                    style: textos.bodyMedium?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: BrandSpacing.space5),
              TextFormField(
                controller: _senhaController,
                obscureText: !_senhaVisivel,
                validator: Validatorless.required('Digite a sua senha'),
                forceErrorText: provider.erroSenha,
                onChanged: (_) => provider.limparErroSenha(),
                decoration: InputDecoration(
                  labelText: 'Sua senha',
                  helperText: 'Para confirmar que é você.',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _senhaVisivel = !_senhaVisivel),
                    icon: Icon(
                      _senhaVisivel
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: BrandSpacing.space5),
              FilledButton(
                onPressed: provider.isLoading ? null : () => _excluir(ehDono),
                style: FilledButton.styleFrom(
                  backgroundColor: cores.danger,
                  foregroundColor: cores.bg,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  ehDono ? 'Excluir o negócio' : 'Excluir minha conta',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
