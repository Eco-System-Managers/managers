import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/compartilhar/whatsapp.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/avatar_iniciais.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:validatorless/validatorless.dart';

import '../../domain/entities/colaborador.dart';
import '../../domain/entities/convite.dart';
import '../../usuarios_provider.dart';
import '../providers/colaborador_provider.dart';
import '../widgets/campos_colaborador.dart';

// a ficha de alguém da equipe: nome, função, vínculo, comissão ou a flag de
// cobrar (editáveis pelo proprietário), convidar para o app quem não tem
// login (e o convite pendente: mandar o link por WhatsApp, reenviar,
// cancelar), desativar/reativar e remover. o proprietário não se desativa
// nem se remove (a API recusa com proprietario_protegido; a tela nem oferece)
class ColaboradorPage extends ConsumerStatefulWidget {
  const ColaboradorPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ColaboradorPage> createState() => _ColaboradorPageState();
}

class _ColaboradorPageState extends ConsumerState<ColaboradorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _funcaoController = TextEditingController();
  final _comissaoController = TextEditingController();
  VinculoColaborador _tipo = VinculoColaborador.parceiro;
  bool _podeCobrar = true;

  // os campos são preenchidos uma vez, quando a ficha chega
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
    _nomeController.dispose();
    _funcaoController.dispose();
    _comissaoController.dispose();
    super.dispose();
  }

  void _preencher(Colaborador c) {
    _nomeController.text = c.nome;
    _funcaoController.text = c.funcao;
    _comissaoController.text = c.comissaoPercentual == null
        ? ''
        : c.comissaoPercentual!.toStringAsFixed(
            c.comissaoPercentual!.isInteger ? 0 : 2,
          );
    _tipo = c.tipo;
    _podeCobrar = c.podeCobrar;
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    await _provider.salvar(
      CamposColaborador.dados(
        nome: _nomeController,
        funcao: _funcaoController,
        comissao: _comissaoController,
        tipo: _tipo,
        podeCobrar: _podeCobrar,
      ),
    );
  }

  Future<void> _convidar(Colaborador c) async {
    final email = await _pedirEmail(c);
    if (email == null || !mounted) return;
    await _provider.convidar(email);
  }

  Future<String?> _pedirEmail(Colaborador c) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convidar para o app'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            validator: Validatorless.multiple([
              Validatorless.required('Informe o e-mail'),
              Validatorless.email('E-mail inválido'),
            ]),
            decoration: InputDecoration(
              labelText: 'E-mail de ${c.nome}',
              helperText: 'A pessoa recebe o link para criar a senha.',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Enviar convite'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  // o mesmo link do e-mail, numa mensagem pronta. sem número: a pessoa da
  // equipe não tem telefone na ficha, então o WhatsApp pede o contato
  Future<void> _mandarPorWhatsApp(Colaborador c, Convite convite) async {
    final negocio = ref.read(negocioAtualProvider).nome;
    final texto =
        'Oi, ${c.nome}! Você foi convidado(a) para a equipe'
        '${negocio.isEmpty ? '' : ' de $negocio'} no Work Manage. '
        'Crie sua senha pelo link: ${convite.link}\n'
        'O link vale até ${formatarData(convite.expiraEm)}.';
    final abriu = await abrirWhatsApp(texto: texto);
    if (!abriu && mounted) _avisar('Não deu para abrir o WhatsApp.');
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
    await _provider.cancelarConvite();
  }

  Future<void> _alterarAtivo(Colaborador c) async {
    final ativar = !c.ativo;
    final ok = await confirmar(
      context,
      titulo: ativar ? 'Reativar' : 'Desativar',
      mensagem: ativar
          ? '${c.nome} volta a aparecer na agenda'
                '${c.temAcesso ? ' e a entrar no app' : ''}.'
          : '${c.nome} sai dos serviços que executa'
                '${c.temAcesso ? ' e perde o acesso na hora' : ''}. '
                'Os atendimentos já marcados continuam.',
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
      mensagem: c.temAcesso
          ? 'A conta de ${c.nome} é apagada e o acesso termina na hora.$aviso'
          : '${c.nome} sai da equipe. O histórico fica guardado.$aviso',
      textoConfirmar: 'Remover',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    await _provider.remover();
  }

  void _avisar(String texto) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(texto)));
      }
    });
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
        if (provider.salvo) _avisar('Ficha salva.');
        if (provider.convidado) _avisar('Convite enviado por e-mail.');
        provider.avisosMostrados();

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
      _preencher(c);
      _preenchido = true;
    }

    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    // o dono não se desativa nem se remove; quem não é dono não mexe em nada
    final podeMexer = souProprietario && !c.ehProprietario;

    return Form(
      key: _formKey,
      child: ListView(
        padding: paddingDaPagina(context),
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
            c.temAcesso ? c.email : 'Sem acesso ao app',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              Chip(
                label: Text(c.ehProprietario ? 'Proprietário' : c.tipo.nome),
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
          if (c.ehProprietario)
            // o dono não tem vínculo nem comissão: só a função
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
            )
          else
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
              habilitado: souProprietario,
              temAcesso: c.temAcesso || provider.convite != null,
            ),
          if (souProprietario) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: provider.isLoading ? null : _salvar,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Salvar'),
            ),
          ],

          if (podeMexer) ...[
            if (!c.temAcesso && provider.convite != null) ...[
              const SizedBox(height: 24),
              _ConvitePendente(
                convite: provider.convite!,
                ocupado: provider.isLoading,
                onWhatsApp: () => _mandarPorWhatsApp(c, provider.convite!),
                onReenviar: provider.reenviarConvite,
                onCancelar: () => _cancelarConvite(provider.convite!),
              ),
            ] else if (!c.temAcesso) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: provider.isLoading ? null : () => _convidar(c),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Convidar para o app'),
              ),
            ],
            const SizedBox(height: 24),
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
      ),
    );
  }
}

// o convite a caminho: para quem foi, até quando vale e o que fazer com ele
class _ConvitePendente extends StatelessWidget {
  const _ConvitePendente({
    required this.convite,
    required this.ocupado,
    required this.onWhatsApp,
    required this.onReenviar,
    required this.onCancelar,
  });

  final Convite convite;
  final bool ocupado;
  final VoidCallback onWhatsApp;
  final VoidCallback onReenviar;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mail_outline, color: colors.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Convite enviado para ${convite.email}',
                      style: textos.bodyMedium?.copyWith(
                        color: colors.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Vale até ${formatarData(convite.expiraEm)}. Se o '
                      'e-mail não chegou, mande o link por WhatsApp.',
                      style: textos.bodySmall?.copyWith(
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            children: [
              TextButton.icon(
                onPressed: ocupado || convite.link.isEmpty ? null : onWhatsApp,
                icon: const Icon(Icons.chat_outlined),
                label: const Text('WhatsApp'),
              ),
              TextButton.icon(
                onPressed: ocupado ? null : onReenviar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reenviar'),
              ),
              TextButton.icon(
                onPressed: ocupado ? null : onCancelar,
                style: TextButton.styleFrom(foregroundColor: colors.error),
                icon: const Icon(Icons.close),
                label: const Text('Cancelar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
