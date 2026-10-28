import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:printing/printing.dart';

import '../../contratos_provider.dart';
import '../../domain/entities/contrato.dart';
import '../pdf/contrato_pdf.dart';
import '../providers/contrato_provider.dart';
import '../widgets/status_contrato_chip.dart';

// a ficha do contrato: o texto congelado, o status e as ações. o PDF é
// gerado aqui e vai pela folha de compartilhar do aparelho; o que acontece
// depois (assinou, recusou) o dono marca à mão
class ContratoPage extends ConsumerStatefulWidget {
  const ContratoPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ContratoPage> createState() => _ContratoPageState();
}

class _ContratoPageState extends ConsumerState<ContratoPage> {
  ContratoProvider get _provider => ref.read(contratoProvider(widget.id));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  Future<void> _compartilhar(Contrato contrato) async {
    final negocioNome = ref.read(negocioAtualProvider).nome;
    final bytes = await gerarPdfDoContrato(contrato, negocioNome: negocioNome);
    final compartilhou = await Printing.sharePdf(
      bytes: bytes,
      filename: '${_nomeDoArquivo(contrato)}.pdf',
      subject: contrato.titulo,
    );
    if (!mounted) return;

    // o primeiro compartilhamento é o envio
    if (compartilhou && contrato.status == StatusContrato.pendente) {
      final marcou = await _provider.marcar(StatusContrato.enviado);
      if (marcou && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Marcado como enviado.')));
      }
    }
  }

  static String _nomeDoArquivo(Contrato contrato) {
    final base = contrato.titulo
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return base.isEmpty ? 'contrato-${contrato.id}' : base;
  }

  Future<void> _marcarAssinado(Contrato contrato) async {
    final nome = await _pedirNomeDoAssinante(contrato.clienteNome);
    if (nome == null || !mounted) return;
    await _provider.marcar(StatusContrato.assinado, nomeAssinante: nome);
  }

  Future<String?> _pedirNomeDoAssinante(String inicial) {
    final controller = TextEditingController(text: inicial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marcar como assinado'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Quem assinou'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _marcarRecusado() async {
    final ok = await confirmar(
      context,
      titulo: 'Marcar como recusado',
      mensagem: 'O cliente não assinou. O contrato fica encerrado.',
      textoConfirmar: 'Recusado',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    await _provider.marcar(StatusContrato.recusado);
  }

  Future<void> _remover() async {
    final ok = await confirmar(
      context,
      titulo: 'Apagar contrato',
      mensagem: 'O contrato some da lista e da ficha do cliente.',
      textoConfirmar: 'Apagar',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    await _provider.remover();
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(contratoProvider(widget.id));

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        if (provider.removido) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop();
          });
        }
        final contrato = provider.contrato;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Contrato'),
            actions: [
              // assinado não se apaga: a API recusa
              if (contrato != null &&
                  contrato.status != StatusContrato.assinado)
                IconButton(
                  tooltip: 'Apagar',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: provider.isLoading ? null : _remover,
                ),
            ],
          ),
          body: _corpo(context, provider, contrato),
        );
      },
    );
  }

  Widget _corpo(
    BuildContext context,
    ContratoProvider provider,
    Contrato? contrato,
  ) {
    if (contrato == null) {
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
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final assinadoEm = contrato.assinadoEm;

    return ListView(
      padding: const EdgeInsets.all(BrandSpacing.space4),
      children: [
        // o título do contrato é o título da ficha: h2
        Text(contrato.titulo, style: BrandText.h2.copyWith(color: cores.ink)),
        const SizedBox(height: BrandSpacing.space2),
        Row(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: BrandSpacing.space1),
            Expanded(
              child: Text(
                contrato.clienteNome,
                style: textos.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            StatusContratoChip(status: contrato.status),
          ],
        ),
        const SizedBox(height: BrandSpacing.space1),
        Text(
          'Gerado em ${formatarDataHora(contrato.criadoEm)}',
          style: textos.bodySmall,
        ),
        if (assinadoEm != null)
          Text(
            'Assinado por ${contrato.nomeAssinante} em '
            '${formatarDataHora(assinadoEm)}',
            style: textos.bodySmall,
          ),

        if (provider.errorMessage != null) ...[
          const SizedBox(height: BrandSpacing.space3),
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

        const SizedBox(height: BrandSpacing.space4),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(BrandSpacing.space4),
            // o texto corrido do contrato na entrelinha do body (22/15)
            child: SelectableText(contrato.corpo, style: textos.bodyMedium),
          ),
        ),

        const SizedBox(height: BrandSpacing.space5),
        FilledButton.icon(
          onPressed: provider.isLoading ? null : () => _compartilhar(contrato),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.share_rounded),
          label: const Text('Compartilhar PDF'),
        ),
        if (!contrato.status.finalizado) ...[
          const SizedBox(height: BrandSpacing.space3),
          OutlinedButton.icon(
            onPressed: provider.isLoading
                ? null
                : () => _marcarAssinado(contrato),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.task_alt_rounded),
            label: const Text('Marcar como assinado'),
          ),
          const SizedBox(height: BrandSpacing.space1),
          // recusa encerra o contrato: danger
          TextButton(
            onPressed: provider.isLoading ? null : _marcarRecusado,
            style: TextButton.styleFrom(foregroundColor: cores.danger),
            child: const Text('Cliente recusou'),
          ),
        ],
      ],
    );
  }
}
