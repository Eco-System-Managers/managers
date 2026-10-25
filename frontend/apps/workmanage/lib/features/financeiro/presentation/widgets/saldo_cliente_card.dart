import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';

import '../../financeiro_provider.dart';

// o crédito do cliente na comanda e as últimas movimentações, para a ficha
// dele. a ficha segue útil se isto falhar: o erro fica dentro do cartão
class SaldoClienteCard extends ConsumerStatefulWidget {
  const SaldoClienteCard({super.key, required this.clienteId});

  final int clienteId;

  @override
  ConsumerState<SaldoClienteCard> createState() => _SaldoClienteCardState();
}

class _SaldoClienteCardState extends ConsumerState<SaldoClienteCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(saldoClienteProvider(widget.clienteId)).carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a ficha estiver aberta
    final provider = ref.watch(saldoClienteProvider(widget.clienteId));
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final saldo = provider.saldo;
        final erro = provider.erro;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Crédito na comanda',
                        style: textos.titleSmall,
                      ),
                    ),
                    if (saldo != null)
                      Text(
                        formatarDinheiro(saldo.saldo),
                        style: textos.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
                  const SizedBox(height: 8),
                  Text(erro.message, style: TextStyle(color: colors.error)),
                  TextButton(
                    onPressed: provider.carregar,
                    child: const Text('Tentar de novo'),
                  ),
                ],
                if (saldo != null && saldo.transacoes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  // as três últimas: o extrato inteiro não cabe na ficha
                  for (final t in saldo.transacoes.reversed.take(3))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${formatarData(t.criadoEm)} · ${t.origemNome}',
                              style: textos.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${t.credito ? '+' : '-'} ${formatarDinheiro(t.valor)}',
                            style: textos.bodySmall?.copyWith(
                              color: t.credito
                                  ? Colors.green.shade700
                                  : colors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
