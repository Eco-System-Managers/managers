import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../assinatura_provider.dart';
import '../../domain/entities/assinatura.dart';
import '../providers/assinatura_provider.dart';

// a assinatura do negócio na plataforma: status, checkout no navegador,
// confirmação do pagamento feito lá fora, cancelamento e o histórico de
// cobranças. é para cá que o 402 traz quem está bloqueado
class AssinaturaPage extends ConsumerStatefulWidget {
  const AssinaturaPage({super.key});

  @override
  ConsumerState<AssinaturaPage> createState() => _AssinaturaPageState();
}

class _AssinaturaPageState extends ConsumerState<AssinaturaPage> {
  AssinaturaProvider get _provider => ref.read(assinaturaProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // o checkout é hospedado pelo gateway: abre no navegador do aparelho
  Future<void> _assinar() async {
    final link = await _provider.iniciar();
    if (link == null || !mounted) return;
    final abriu = await launchUrl(
      Uri.parse(link),
      mode: LaunchMode.externalApplication,
    );
    if (!abriu && mounted) _avisar('Não foi possível abrir o navegador.');
  }

  // o retorno do checkout cai na web; sem deep link, a pessoa informa o id
  // da assinatura (preapproval_id) para vincular ao negócio
  Future<void> _confirmar() async {
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar assinatura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Informe o id da assinatura mostrado ao final do pagamento '
              '(preapproval_id).',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Id da assinatura',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (id == null || id.trim().isEmpty || !mounted) return;
    final ok = await _provider.confirmar(id);
    if (ok && mounted) _avisar('Assinatura confirmada.');
  }

  Future<void> _cancelar() async {
    final ok = await confirmar(
      context,
      titulo: 'Cancelar assinatura',
      mensagem:
          'O acesso continua até o fim do período já pago. Depois '
          'disso, o app fica bloqueado até uma nova assinatura.',
      textoConfirmar: 'Cancelar assinatura',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    final cancelou = await _provider.cancelar();
    if (cancelou && mounted) _avisar('Assinatura cancelada.');
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(assinaturaProvider);
    final negocio = ref.watch(negocioAtualProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Assinatura')),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) => _corpo(provider, negocio.ehProprietario),
      ),
    );
  }

  Widget _corpo(AssinaturaProvider provider, bool souProprietario) {
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
    final assinatura = provider.assinatura;
    final bloqueio = provider.mensagemDeBloqueio;

    return RefreshIndicator(
      onRefresh: provider.carregar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (provider.isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),

          if (bloqueio != null) ...[
            const SizedBox(height: 8),
            _Aviso(texto: bloqueio, icone: Icons.lock_outline, erro: true),
          ],
          if (provider.errorMessage != null) ...[
            const SizedBox(height: 8),
            _Aviso(
              texto: provider.errorMessage!,
              icone: Icons.error_outline,
              erro: true,
            ),
          ],

          const SizedBox(height: 16),
          if (assinatura == null)
            _Aviso(
              texto: 'Este negócio ainda não tem assinatura.',
              icone: Icons.info_outline,
              erro: false,
            )
          else
            _CartaoAssinatura(assinatura: assinatura),

          const SizedBox(height: 24),
          if (!souProprietario)
            Text(
              'Só o proprietário pode alterar a assinatura.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            )
          else ...[
            if (provider.podeAssinar) ...[
              FilledButton.icon(
                onPressed: provider.isLoading ? null : _assinar,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Assinar agora'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: provider.isLoading ? null : _confirmar,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Já paguei: confirmar assinatura'),
              ),
            ],
            if (assinatura?.status == StatusAssinatura.ativa) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: provider.isLoading ? null : _cancelar,
                style: TextButton.styleFrom(foregroundColor: colors.error),
                child: const Text('Cancelar assinatura'),
              ),
            ],
          ],

          const SizedBox(height: 24),
          Text('Cobranças', style: textos.titleMedium),
          const SizedBox(height: 4),
          if (provider.pagamentos.isEmpty)
            Text(
              'Nenhuma cobrança ainda.',
              style: TextStyle(color: colors.onSurfaceVariant),
            )
          else
            for (final p in provider.pagamentos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  switch (p.status) {
                    StatusPagamentoAssinatura.pago =>
                      Icons.check_circle_outline,
                    StatusPagamentoAssinatura.pendente => Icons.schedule,
                    StatusPagamentoAssinatura.falhou => Icons.error_outline,
                  },
                  color: switch (p.status) {
                    StatusPagamentoAssinatura.pago => Colors.green.shade700,
                    StatusPagamentoAssinatura.pendente =>
                      colors.onSurfaceVariant,
                    StatusPagamentoAssinatura.falhou => colors.error,
                  },
                ),
                title: Text(formatarDinheiro(p.valor)),
                subtitle: Text(formatarData(p.data)),
                trailing: Text(p.status.nome),
              ),
        ],
      ),
    );
  }
}

class _CartaoAssinatura extends StatelessWidget {
  const _CartaoAssinatura({required this.assinatura});

  final Assinatura assinatura;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final a = assinatura;
    final cor = switch (a.status) {
      StatusAssinatura.ativa => Colors.green.shade700,
      StatusAssinatura.trial => colors.primary,
      StatusAssinatura.cancelada => colors.outline,
      StatusAssinatura.inadimplente => colors.error,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.planoNome.isEmpty ? 'Plano' : 'Plano ${a.planoNome}',
                  style: textos.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Chip(
                label: Text(a.status.nome),
                labelStyle: TextStyle(color: cor, fontSize: 12),
                side: BorderSide(color: cor.withValues(alpha: 0.5)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Linha(rotulo: 'Início', valor: formatarData(a.inicio)),
          if (a.status == StatusAssinatura.trial && a.trialFim != null)
            _Linha(rotulo: 'Teste até', valor: formatarData(a.trialFim!))
          else
            _Linha(
              rotulo: a.status == StatusAssinatura.cancelada
                  ? 'Acesso até'
                  : 'Próximo vencimento',
              valor: formatarData(a.proximoVencimento),
            ),
          if (a.bloqueada) ...[
            const SizedBox(height: 8),
            Text(
              'Acesso bloqueado',
              style: TextStyle(
                color: colors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.rotulo, required this.valor});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rotulo,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          Text(valor),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.icone, required this.erro});

  final String texto;
  final IconData icone;
  final bool erro;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fundo = erro ? colors.errorContainer : colors.secondaryContainer;
    final frente = erro ? colors.onErrorContainer : colors.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icone, color: frente),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto, style: TextStyle(color: frente)),
          ),
        ],
      ),
    );
  }
}
