import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/dinheiro_input_formatter.dart';

import '../../domain/entities/agendamento.dart';
import '../../domain/params/agenda_params.dart';

// a folha de cobrança: desconto, crédito do cliente, uma ou mais formas de
// pagamento e o troco que fica como crédito. a soma precisa fechar com o
// total: a API recusa (soma_invalida) e a tela já mostra o que falta
class CobrancaSheet extends StatefulWidget {
  const CobrancaSheet({
    super.key,
    required this.agendamento,
    required this.creditoDisponivel,
    required this.onCobrar,
  });

  final Agendamento agendamento;
  final Decimal creditoDisponivel;

  // devolve null quando cobrou; senão, a mensagem de erro para mostrar
  final Future<String?> Function(CobrancaParams params) onCobrar;

  // devolve true quando a cobrança foi feita
  static Future<bool> abrir(
    BuildContext context, {
    required Agendamento agendamento,
    required Decimal creditoDisponivel,
    required Future<String?> Function(CobrancaParams params) onCobrar,
  }) async {
    final cobrou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CobrancaSheet(
        agendamento: agendamento,
        creditoDisponivel: creditoDisponivel,
        onCobrar: onCobrar,
      ),
    );
    return cobrou ?? false;
  }

  @override
  State<CobrancaSheet> createState() => _CobrancaSheetState();
}

class _LinhaPagamento {
  _LinhaPagamento(this.forma, String valor)
    : controller = TextEditingController(text: valor);

  FormaPagamento forma;
  final TextEditingController controller;

  Decimal? get valor => dinheiroDoTexto(controller.text);
}

class _CobrancaSheetState extends State<CobrancaSheet> {
  final _descontoController = TextEditingController();
  final _creditoController = TextEditingController();
  final _trocoController = TextEditingController();
  late final List<_LinhaPagamento> _linhas;

  String? _erro;
  bool _enviando = false;

  Decimal get _zero => Decimal.fromInt(0);

  @override
  void initState() {
    super.initState();
    // a primeira linha já vem com o total: o caso comum é uma forma só
    _linhas = [
      _LinhaPagamento(
        FormaPagamento.dinheiro,
        DinheiroInputFormatter.formatar(widget.agendamento.valorDosServicos),
      ),
    ];
  }

  @override
  void dispose() {
    _descontoController.dispose();
    _creditoController.dispose();
    _trocoController.dispose();
    for (final l in _linhas) {
      l.controller.dispose();
    }
    super.dispose();
  }

  Decimal get _desconto => dinheiroDoTexto(_descontoController.text) ?? _zero;
  Decimal get _credito => dinheiroDoTexto(_creditoController.text) ?? _zero;
  Decimal get _troco => dinheiroDoTexto(_trocoController.text) ?? _zero;

  Decimal get _total => widget.agendamento.valorDosServicos - _desconto;

  Decimal get _pago =>
      _linhas.fold(_zero, (soma, l) => soma + (l.valor ?? _zero)) + _credito;

  Decimal get _diferenca => _total - _pago;

  bool get _creditoValido =>
      _credito <= widget.creditoDisponivel && _credito <= _total;

  bool get _podeConfirmar =>
      !_enviando &&
      _diferenca == _zero &&
      _total >= _zero &&
      _creditoValido &&
      _linhas.every((l) => l.valor != null && l.valor! > _zero);

  void _adicionarLinha() {
    setState(() {
      final falta = _diferenca > _zero ? _diferenca : _zero;
      _linhas.add(
        _LinhaPagamento(
          FormaPagamento.pix,
          falta > _zero ? DinheiroInputFormatter.formatar(falta) : '',
        ),
      );
    });
  }

  void _removerLinha(_LinhaPagamento linha) {
    setState(() {
      _linhas.remove(linha);
      linha.controller.dispose();
    });
  }

  Future<void> _confirmar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });
    final erro = await widget.onCobrar(
      CobrancaParams(
        id: widget.agendamento.id,
        pagamentos: [
          for (final l in _linhas) Pagamento(forma: l.forma, valor: l.valor!),
        ],
        desconto: _desconto,
        creditoAplicado: _credito,
        trocoCredito: _troco,
      ),
    );
    if (!mounted) return;
    if (erro == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _enviando = false;
      _erro = erro;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final temCredito = widget.creditoDisponivel > _zero;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Text('Cobrar atendimento', style: textos.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Serviços: ${formatarDinheiro(widget.agendamento.valorDosServicos)}',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _descontoController,
            keyboardType: TextInputType.number,
            inputFormatters: const [DinheiroInputFormatter()],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Desconto (opcional)',
              prefixText: 'R\$ ',
              border: OutlineInputBorder(),
            ),
          ),

          if (temCredito) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _creditoController,
              keyboardType: TextInputType.number,
              inputFormatters: const [DinheiroInputFormatter()],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Usar crédito do cliente',
                helperText:
                    'Disponível: ${formatarDinheiro(widget.creditoDisponivel)}',
                errorText: _creditoValido
                    ? null
                    : 'Maior que o disponível ou que o total',
                prefixText: 'R\$ ',
                border: const OutlineInputBorder(),
              ),
            ),
          ],

          const SizedBox(height: 24),
          Text('Pagamento', style: textos.titleSmall),
          const SizedBox(height: 8),
          for (final linha in _linhas) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<FormaPagamento>(
                    key: ValueKey(linha),
                    initialValue: linha.forma,
                    items: [
                      for (final f in FormaPagamento.values)
                        DropdownMenuItem(value: f, child: Text(f.nome)),
                    ],
                    onChanged: (f) => setState(() => linha.forma = f!),
                    decoration: const InputDecoration(
                      labelText: 'Forma',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: linha.controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [DinheiroInputFormatter()],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      prefixText: 'R\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                if (_linhas.length > 1)
                  IconButton(
                    tooltip: 'Remover',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _removerLinha(linha),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _adicionarLinha,
              icon: const Icon(Icons.add),
              label: const Text('Outra forma de pagamento'),
            ),
          ),

          const SizedBox(height: 8),
          TextField(
            controller: _trocoController,
            keyboardType: TextInputType.number,
            inputFormatters: const [DinheiroInputFormatter()],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Troco que fica como crédito (opcional)',
              helperText: 'Entra na comanda do cliente para a próxima vez',
              prefixText: 'R\$ ',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 16),
          _Resumo(total: _total, pago: _pago, diferenca: _diferenca),

          if (_erro != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _erro!,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],

          const SizedBox(height: 16),
          FilledButton(
            onPressed: _podeConfirmar ? _confirmar : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(_enviando ? 'Cobrando...' : 'Confirmar cobrança'),
          ),
        ],
      ),
    );
  }
}

// total a cobrar, quanto já está lançado e o que falta ou sobra
class _Resumo extends StatelessWidget {
  const _Resumo({
    required this.total,
    required this.pago,
    required this.diferenca,
  });

  final Decimal total;
  final Decimal pago;
  final Decimal diferenca;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final zero = Decimal.fromInt(0);
    final fecha = diferenca == zero;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total a cobrar', style: textos.bodySmall),
                Text(
                  formatarDinheiro(total),
                  style: textos.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Lançado ${formatarDinheiro(pago)}',
                style: textos.bodySmall,
              ),
              Text(
                fecha
                    ? 'Confere'
                    : diferenca > zero
                    ? 'Falta ${formatarDinheiro(diferenca)}'
                    : 'Sobra ${formatarDinheiro(-diferenca)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: fecha ? Colors.green.shade700 : colors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
