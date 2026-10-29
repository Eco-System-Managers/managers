import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/selo_de_status.dart';
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
            const SizedBox(height: BrandSpacing.space3),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Id da assinatura'),
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
      textoCancelar: 'Voltar',
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

    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final assinatura = provider.assinatura;
    final bloqueio = provider.mensagemDeBloqueio;

    return RefreshIndicator(
      onRefresh: provider.carregar,
      child: ListView(
        padding: const EdgeInsets.all(BrandSpacing.space4),
        children: [
          if (provider.isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),

          if (bloqueio != null) ...[
            const SizedBox(height: BrandSpacing.space2),
            _Aviso(
              texto: bloqueio,
              icone: Icons.lock_outline_rounded,
              erro: true,
            ),
          ],
          if (provider.errorMessage != null) ...[
            const SizedBox(height: BrandSpacing.space2),
            _Aviso(
              texto: provider.errorMessage!,
              icone: Icons.error_outline_rounded,
              erro: true,
            ),
          ],

          const SizedBox(height: BrandSpacing.space4),
          if (assinatura == null)
            _Aviso(
              texto: 'Este negócio ainda não tem assinatura.',
              icone: Icons.info_outline_rounded,
              erro: false,
            )
          else
            _CartaoAssinatura(assinatura: assinatura),

          const SizedBox(height: BrandSpacing.space5),
          if (!souProprietario)
            Text(
              'Só o proprietário pode alterar a assinatura.',
              textAlign: TextAlign.center,
              style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
            )
          else ...[
            if (provider.podeAssinar && !provider.checkoutAberto) ...[
              // a fase de testes: o checkout fica fechado, na API também
              const _Aviso(
                texto:
                    'A assinatura pelo app chega em breve. Por enquanto, '
                    'use o app normalmente.',
                icone: Icons.schedule_rounded,
                erro: false,
              ),
              const SizedBox(height: BrandSpacing.space3),
              FilledButton.icon(
                onPressed: null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.lock_clock_rounded),
                label: const Text('Em breve'),
              ),
            ] else if (provider.podeAssinar) ...[
              FilledButton.icon(
                onPressed: provider.isLoading ? null : _assinar,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Assinar agora'),
              ),
              const SizedBox(height: BrandSpacing.space3),
              OutlinedButton.icon(
                onPressed: provider.isLoading ? null : _confirmar,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.verified_rounded),
                label: const Text('Já paguei: confirmar assinatura'),
              ),
            ],
            if (assinatura?.status == StatusAssinatura.ativa) ...[
              const SizedBox(height: BrandSpacing.space3),
              // cancelar encerra o acesso: danger
              TextButton(
                onPressed: provider.isLoading ? null : _cancelar,
                style: TextButton.styleFrom(foregroundColor: cores.danger),
                child: const Text('Cancelar assinatura'),
              ),
            ],
          ],

          const SizedBox(height: BrandSpacing.space5),
          Text('Cobranças', style: textos.titleLarge),
          const SizedBox(height: BrandSpacing.space1),
          if (provider.pagamentos.isEmpty)
            Text(
              'Nenhuma cobrança ainda.',
              style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
            )
          else
            // pago é success, pendente é atenção e falha é danger: a cor
            // vai no ícone e no texto do status
            for (final p in provider.pagamentos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(switch (p.status) {
                  StatusPagamentoAssinatura.pago =>
                    Icons.check_circle_outline_rounded,
                  StatusPagamentoAssinatura.pendente => Icons.schedule_rounded,
                  StatusPagamentoAssinatura.falhou =>
                    Icons.error_outline_rounded,
                }, color: _corDoPagamento(p.status, cores)),
                title: Text(formatarDinheiro(p.valor)),
                subtitle: Text(formatarData(p.data)),
                trailing: Text(
                  p.status.nome,
                  style: textos.labelMedium?.copyWith(
                    color: _corDoPagamento(p.status, cores),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static Color _corDoPagamento(
    StatusPagamentoAssinatura status,
    BrandColors cores,
  ) {
    return switch (status) {
      StatusPagamentoAssinatura.pago => cores.success,
      StatusPagamentoAssinatura.pendente => cores.warning,
      StatusPagamentoAssinatura.falhou => cores.danger,
    };
  }
}

class _CartaoAssinatura extends StatelessWidget {
  const _CartaoAssinatura({required this.assinatura});

  final Assinatura assinatura;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final a = assinatura;
    // ativa é success; o teste é atenção, porque acaba numa data; cancelada
    // e inadimplente levam ao bloqueio: danger
    final cor = switch (a.status) {
      StatusAssinatura.ativa => cores.success,
      StatusAssinatura.trial => cores.warning,
      StatusAssinatura.cancelada => cores.danger,
      StatusAssinatura.inadimplente => cores.danger,
    };

    // o cartão do tema: fundo da página com borda, sem sombra
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(BrandSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    a.planoNome.isEmpty ? 'Plano' : 'Plano ${a.planoNome}',
                    style: textos.titleLarge,
                  ),
                ),
                SeloDeStatus(texto: a.status.nome, cor: cor),
              ],
            ),
            const SizedBox(height: BrandSpacing.space2),
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
              const SizedBox(height: BrandSpacing.space2),
              Text(
                'Acesso bloqueado',
                style: textos.titleMedium?.copyWith(color: cores.danger),
              ),
            ],
          ],
        ),
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
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BrandSpacing.space1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rotulo,
              style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
            ),
          ),
          Text(valor, style: textos.bodyMedium),
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
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    // a caixa de erro é o fundo 2 com texto danger; o aviso neutro é o
    // destaque em azul suave com texto ink
    final fundo = erro ? colors.errorContainer : cores.blueSoft;
    final frente = erro ? colors.onErrorContainer : cores.ink;
    return Container(
      padding: const EdgeInsets.all(BrandSpacing.space3),
      decoration: BoxDecoration(color: fundo, borderRadius: BrandRadius.mdAll),
      child: Row(
        children: [
          Icon(icone, color: frente),
          const SizedBox(width: BrandSpacing.space3),
          Expanded(
            child: Text(
              texto,
              style: textos.bodyMedium?.copyWith(color: frente),
            ),
          ),
        ],
      ),
    );
  }
}
