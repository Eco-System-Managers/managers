import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:validatorless/validatorless.dart';

import '../../usuarios_provider.dart';
import '../providers/aceitar_convite_provider.dart';

// a tela do link do convite (rota pública): mostra para quem é, recebe a
// senha e entra direto. o link chega por e-mail; sem deep link ainda, a
// pessoa cola o link ou o token na tela de login
class AceitarConvitePage extends ConsumerStatefulWidget {
  const AceitarConvitePage({super.key, required this.token});

  final String token;

  @override
  ConsumerState<AceitarConvitePage> createState() => _AceitarConvitePageState();
}

class _AceitarConvitePageState extends ConsumerState<AceitarConvitePage> {
  final _formKey = GlobalKey<FormState>();
  final _senhaController = TextEditingController();
  final _confirmacaoController = TextEditingController();
  bool _mostrarSenha = false;

  AceitarConviteProvider get _provider =>
      ref.read(aceitarConviteProvider(widget.token));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  @override
  void dispose() {
    _senhaController.dispose();
    _confirmacaoController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    await _provider.aceitar(_senhaController.text);
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(aceitarConviteProvider(widget.token));
    final colors = Theme.of(context).colorScheme;
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Convite para a equipe')),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          if (provider.aceito) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/home');
            });
          }

          final info = provider.info;
          if (info == null) {
            final erro = provider.erroAoCarregar;
            if (erro != null) {
              return _ConviteInvalido(mensagem: erro.message);
            }
            return const Carregando();
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: paddingDaPagina(context),
              children: [
                // ícone decorativo: neutro, porque o azul é só da ação
                Icon(Icons.badge_rounded, size: 56, color: cores.inkMuted),
                const SizedBox(height: BrandSpacing.space4),
                Text(
                  info.nome.isEmpty
                      ? 'Você recebeu um convite para a equipe'
                      : 'Olá, ${info.nome}. Você recebeu um convite para a '
                            'equipe',
                  textAlign: TextAlign.center,
                  style: textos.titleLarge,
                ),
                const SizedBox(height: BrandSpacing.space2),
                Text(
                  'Crie a senha da sua conta (${info.email}). O convite vale '
                  'até ${formatarDataHora(info.expiraEm)}.',
                  textAlign: TextAlign.center,
                  style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
                ),
                const SizedBox(height: BrandSpacing.space5),

                if (provider.errorMessage != null) ...[
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
                  const SizedBox(height: BrandSpacing.space4),
                ],

                TextFormField(
                  controller: _senhaController,
                  obscureText: !_mostrarSenha,
                  textInputAction: TextInputAction.next,
                  validator: Validatorless.multiple([
                    Validatorless.required('Informe a senha'),
                    Validatorless.min(8, 'No mínimo 8 caracteres'),
                  ]),
                  forceErrorText: provider.erroDoCampo('senha'),
                  onChanged: (_) => provider.limparErroDoCampo('senha'),
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _mostrarSenha
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      onPressed: () =>
                          setState(() => _mostrarSenha = !_mostrarSenha),
                    ),
                  ),
                ),
                const SizedBox(height: BrandSpacing.space4),
                TextFormField(
                  controller: _confirmacaoController,
                  obscureText: !_mostrarSenha,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _entrar(),
                  validator: (valor) => valor != _senhaController.text
                      ? 'As senhas não conferem'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar senha',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: BrandSpacing.space5),
                FilledButton(
                  onPressed: provider.isLoading ? null : _entrar,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Criar senha e entrar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// convite inexistente, já usado ou expirado: o detail da API diz qual
class _ConviteInvalido extends StatelessWidget {
  const _ConviteInvalido({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BrandSpacing.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off_rounded, size: 56, color: cores.danger),
            const SizedBox(height: BrandSpacing.space4),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: textos.titleMedium,
            ),
            const SizedBox(height: BrandSpacing.space2),
            Text(
              'Peça um novo convite para o proprietário do negócio.',
              textAlign: TextAlign.center,
              style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
            ),
            const SizedBox(height: BrandSpacing.space5),
            FilledButton(
              onPressed: () => context.go('/login'),
              child: const Text('Ir para o login'),
            ),
          ],
        ),
      ),
    );
  }
}
