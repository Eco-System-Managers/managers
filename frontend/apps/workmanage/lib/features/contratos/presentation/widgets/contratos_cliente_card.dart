import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';

import '../../contratos_provider.dart';
import 'status_contrato_chip.dart';

// os contratos do cliente, para a ficha dele: os últimos e o atalho de
// gerar. a ficha segue útil se isto falhar: o erro fica dentro do cartão
class ContratosClienteCard extends ConsumerStatefulWidget {
  const ContratosClienteCard({super.key, required this.clienteId});

  final int clienteId;

  // quantos cabem na ficha
  static const recentes = 5;

  @override
  ConsumerState<ContratosClienteCard> createState() =>
      _ContratosClienteCardState();
}

class _ContratosClienteCardState extends ConsumerState<ContratosClienteCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(contratosClienteProvider(widget.clienteId)).carregar();
      }
    });
  }

  // a tela aberta pode ter mudado o status: a lista vem da API de novo
  Future<void> _abrir(int id) async {
    await context.push('/mais/contratos/$id');
    if (mounted) {
      ref.read(contratosClienteProvider(widget.clienteId)).carregar();
    }
  }

  // a geração devolve o id do contrato criado: abre a ficha dele em seguida
  Future<void> _gerar() async {
    final id = await context.push<int>(
      '/mais/contratos/gerar?cliente=${widget.clienteId}',
    );
    if (!mounted) return;
    if (id != null) {
      await _abrir(id);
    } else {
      ref.read(contratosClienteProvider(widget.clienteId)).carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a ficha estiver aberta
    final provider = ref.watch(contratosClienteProvider(widget.clienteId));
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final erro = provider.erro;
        final recentes = provider.contratos
            .take(ContratosClienteCard.recentes)
            .toList();

        // o mesmo cartão dos outros blocos da ficha: título h3 e ícone
        // neutro, porque o azul é só da ação
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: BrandSpacing.space4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BrandSpacing.space4,
              BrandSpacing.space4,
              BrandSpacing.space4,
              BrandSpacing.space2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: BrandSpacing.space2),
                    Expanded(
                      child: Text('Contratos', style: textos.titleLarge),
                    ),
                    if (provider.carregado)
                      Text(
                        provider.contratos.isEmpty
                            ? 'nenhum'
                            : '${provider.contratos.length}',
                        style: textos.bodySmall,
                      )
                    else if (erro == null)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                if (erro != null) ...[
                  const SizedBox(height: BrandSpacing.space2),
                  Text(
                    erro.message,
                    style: textos.bodyMedium?.copyWith(color: colors.error),
                  ),
                  TextButton(
                    onPressed: provider.carregar,
                    child: const Text('Tentar de novo'),
                  ),
                ],
                for (final c in recentes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(c.titulo),
                    subtitle: Text(formatarData(c.criadoEm)),
                    trailing: StatusContratoChip(status: c.status),
                    onTap: () => _abrir(c.id),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _gerar,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Gerar contrato'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
