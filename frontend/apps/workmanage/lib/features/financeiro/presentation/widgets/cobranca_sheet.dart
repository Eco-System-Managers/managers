import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/dinheiro_input_formatter.dart';
import 'package:managers/core/widgets/folha.dart';

import '../../domain/entities/pagamento.dart';
import '../../domain/params/cobranca_params.dart';

// a folha de cobrança, igual para a agenda e o kanban: desconto, crédito do
// cliente, uma ou mais formas de pagamento e o troco. a pessoa lança o que o
// cliente entregou; o que passa do total em dinheiro é troco, devolvido ou
// deixado como crédito. a API quer a soma fechando com o total
// (soma_invalida): a folha desconta o troco da linha de dinheiro ao mandar
class CobrancaSheet extends StatefulWidget {
  const CobrancaSheet({
    super.key,
    required this.atendimentoId,
    required this.valorServicos,
    required this.creditoDisponivel,
    required this.onCobrar,
  });

  // o id do agendamento ou do atendimento do kanban
  final int atendimentoId;

  // o total dos serviços antes do desconto
  final Decimal valorServicos;
  final Decimal creditoDisponivel;

  // devolve null quando cobrou; senão, a mensagem de erro para mostrar
  final Future<String?> Function(CobrancaParams params) onCobrar;

  // devolve true quando a cobrança foi feita
  static Future<bool> abrir(
    BuildContext context, {
    required int atendimentoId,
    required Decimal valorServicos,
    required Decimal creditoDisponivel,
    required Future<String?> Function(CobrancaParams params) onCobrar,
  }) async {
    final cobrou = await abrirFolha<bool>(
      context,
      builder: (_) => CobrancaSheet(
        atendimentoId: atendimentoId,
        valorServicos: valorServicos,
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
  late final List<_LinhaPagamento> _linhas;

  // o troco vira crédito na comanda do cliente, em vez de voltar em dinheiro
  bool _trocoComoCredito = false;

  // a primeira linha nasce com o total e o acompanha (desconto, crédito)
  // enquanto ninguém mexer no valor dela: senão, um desconto deixava a
  // linha com o valor cheio, e só em dinheiro isso passava (como troco)
  bool _valorMexido = false;

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
        DinheiroInputFormatter.formatar(widget.valorServicos),
      ),
    ];
  }

  @override
  void dispose() {
    _descontoController.dispose();
    _creditoController.dispose();
    for (final l in _linhas) {
      l.controller.dispose();
    }
    super.dispose();
  }

  Decimal get _desconto => dinheiroDoTexto(_descontoController.text) ?? _zero;
  Decimal get _credito => dinheiroDoTexto(_creditoController.text) ?? _zero;
  Decimal get _total => widget.valorServicos - _desconto;

  Decimal get _pago =>
      _linhas.fold(_zero, (soma, l) => soma + (l.valor ?? _zero)) + _credito;

  Decimal get _diferenca => _total - _pago;

  // o que passou do total e o que foi lançado em dinheiro. só é troco quando
  // há dinheiro na mesa para devolver: cartão e PIX não dão troco, então o
  // que passa neles é erro de digitação
  Decimal get _excedente => _diferenca < _zero ? -_diferenca : _zero;

  Decimal get _dinheiro => _linhas
      .where((l) => l.forma == FormaPagamento.dinheiro)
      .fold(_zero, (soma, l) => soma + (l.valor ?? _zero));

  bool get _temTroco => _excedente > _zero && _excedente <= _dinheiro;

  bool get _creditoValido =>
      _credito <= widget.creditoDisponivel && _credito <= _total;

  bool get _podeConfirmar =>
      !_enviando &&
      (_diferenca == _zero || _temTroco) &&
      _total >= _zero &&
      _creditoValido &&
      _linhas.every((l) => l.valor != null && l.valor! > _zero);

  void _acompanharTotal() {
    if (_valorMexido || _linhas.length != 1) return;
    final restante = _total - _credito;
    _linhas.single.controller.text = restante > _zero
        ? DinheiroInputFormatter.formatar(restante)
        : '';
  }

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

  // os pagamentos como a API espera: o troco sai das linhas de dinheiro
  // (o negócio fica só com o que é dele), e uma linha que zerar não vai
  List<Pagamento> _pagamentos() {
    var troco = _excedente;
    final pagamentos = <Pagamento>[];
    for (final l in _linhas) {
      var valor = l.valor!;
      if (l.forma == FormaPagamento.dinheiro && troco > _zero) {
        final devolvido = valor < troco ? valor : troco;
        valor -= devolvido;
        troco -= devolvido;
      }
      if (valor > _zero) {
        pagamentos.add(Pagamento(forma: l.forma, valor: valor));
      }
    }
    return pagamentos;
  }

  Future<void> _confirmar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });
    final erro = await widget.onCobrar(
      CobrancaParams(
        id: widget.atendimentoId,
        pagamentos: _pagamentos(),
        desconto: _desconto,
        creditoAplicado: _credito,
        trocoCredito: _trocoComoCredito ? _excedente : _zero,
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

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text('Cobrar atendimento', style: textos.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Serviços: ${formatarDinheiro(widget.valorServicos)}',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _descontoController,
          keyboardType: TextInputType.number,
          inputFormatters: const [DinheiroInputFormatter()],
          onChanged: (_) => setState(_acompanharTotal),
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
            onChanged: (_) => setState(_acompanharTotal),
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
                  onChanged: (_) => setState(() => _valorMexido = true),
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

        if (_temTroco) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Deixar o troco de ${formatarDinheiro(_excedente)} como crédito',
            ),
            subtitle: const Text(
              'Entra na comanda do cliente para a próxima vez. Desligado, o '
              'troco volta em dinheiro.',
            ),
            value: _trocoComoCredito,
            onChanged: (v) => setState(() => _trocoComoCredito = v),
          ),
        ],

        const SizedBox(height: 16),
        _Resumo(
          total: _total,
          pago: _pago,
          diferenca: _diferenca,
          temTroco: _temTroco,
        ),

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
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(_enviando ? 'Cobrando...' : 'Confirmar cobrança'),
        ),
      ],
    );
  }
}

// total a cobrar, quanto já está lançado e o que falta, o troco ou o que
// passou sem ter dinheiro para devolver
class _Resumo extends StatelessWidget {
  const _Resumo({
    required this.total,
    required this.pago,
    required this.diferenca,
    required this.temTroco,
  });

  final Decimal total;
  final Decimal pago;
  final Decimal diferenca;
  final bool temTroco;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final zero = Decimal.fromInt(0);
    final fecha = diferenca == zero;
    final ok = fecha || temTroco;

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
                    : temTroco
                    ? 'Troco ${formatarDinheiro(-diferenca)}'
                    : 'Passa ${formatarDinheiro(-diferenca)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ok ? Colors.green.shade700 : colors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
