import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/dinheiro_input_formatter.dart';
import 'package:managers/core/widgets/filtros.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';

import '../../domain/entities/pagamento.dart';
import '../../domain/params/cobranca_params.dart';

// a folha de cobrança, igual para a agenda e o kanban: desconto, crédito do
// cliente, uma ou mais formas de pagamento e o troco. a pessoa lança o que o
// cliente entregou; o que passa do total em dinheiro é troco, devolvido ou
// deixado como crédito. a API quer a soma fechando com o total
// (soma_invalida): a folha desconta o troco da linha de dinheiro ao mandar.
// o que se acerta com o cliente na hora (trocar o serviço pelo que foi feito
// de verdade, um acréscimo com o motivo) fica numa seção fechada: sem mexer
// nela, cobra o combinado
class CobrancaSheet extends StatefulWidget {
  const CobrancaSheet({
    super.key,
    required this.atendimentoId,
    required this.valorServicos,
    required this.creditoDisponivel,
    required this.onCobrar,
    this.permiteCredito = true,
    this.servicos,
    this.servicoAtualId,
    this.servicoAtualNome = '',
    this.avisoTempo,
  });

  // o id do agendamento ou do atendimento do kanban
  final int atendimentoId;

  // o total dos serviços combinados, antes do desconto
  final Decimal valorServicos;
  final Decimal creditoDisponivel;

  // devolve null quando cobrou; senão, a mensagem de erro para mostrar
  final Future<String?> Function(CobrancaParams params) onCobrar;

  // false quando não há comanda (o avulso da esteira): sem usar crédito e
  // sem deixar o troco como crédito (a API recusa com avulso_sem_credito)
  final bool permiteCredito;

  // os serviços pelos quais dá para trocar o combinado (na esteira, os que
  // servem para o porte do veículo ou pet). null ou vazio: sem a troca
  final List<Servico>? servicos;

  // o serviço combinado, para marcar na escolha e voltar a ele
  final int? servicoAtualId;
  final String servicoAtualNome;

  // o aviso de que o atendimento passou do tempo previsto (só na esteira):
  // a pessoa decide se inclui um acréscimo. null sem aviso
  final String? avisoTempo;

  // devolve true quando a cobrança foi feita
  static Future<bool> abrir(
    BuildContext context, {
    required int atendimentoId,
    required Decimal valorServicos,
    required Decimal creditoDisponivel,
    required Future<String?> Function(CobrancaParams params) onCobrar,
    bool permiteCredito = true,
    List<Servico>? servicos,
    int? servicoAtualId,
    String servicoAtualNome = '',
    String? avisoTempo,
  }) async {
    final cobrou = await abrirFolha<bool>(
      context,
      builder: (_) => CobrancaSheet(
        atendimentoId: atendimentoId,
        valorServicos: valorServicos,
        creditoDisponivel: creditoDisponivel,
        onCobrar: onCobrar,
        permiteCredito: permiteCredito,
        servicos: servicos,
        servicoAtualId: servicoAtualId,
        servicoAtualNome: servicoAtualNome,
        avisoTempo: avisoTempo,
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
  // os motivos mais comuns, para não digitar
  static const _motivosSugeridos = [
    'Tempo excedido',
    'Sujeira pesada',
    'Serviço extra',
  ];

  final _descontoController = TextEditingController();
  final _creditoController = TextEditingController();
  final _acrescimoController = TextEditingController();
  final _motivoController = TextEditingController();
  late final List<_LinhaPagamento> _linhas;

  // o troco vira crédito na comanda do cliente, em vez de voltar em dinheiro
  bool _trocoComoCredito = false;

  // a primeira linha nasce com o total e o acompanha (desconto, crédito,
  // troca, acréscimo) enquanto ninguém mexer no valor dela: senão, um
  // desconto deixava a linha com o valor cheio, e só em dinheiro isso
  // passava (como troco)
  bool _valorMexido = false;

  // a seção do combinado está aberta
  bool _ajustando = false;

  // o serviço escolhido no lugar do combinado; null cobra o combinado
  Servico? _servicoTrocado;

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
    _acrescimoController.dispose();
    _motivoController.dispose();
    for (final l in _linhas) {
      l.controller.dispose();
    }
    super.dispose();
  }

  // há para o que trocar: a lista veio e o combinado é conhecido
  bool get _podeTrocar =>
      (widget.servicos?.isNotEmpty ?? false) && widget.servicoAtualId != null;

  Decimal get _desconto => dinheiroDoTexto(_descontoController.text) ?? _zero;
  Decimal get _credito => dinheiroDoTexto(_creditoController.text) ?? _zero;
  Decimal get _acrescimo => dinheiroDoTexto(_acrescimoController.text) ?? _zero;

  // o preço do que vai ser cobrado: o serviço trocado (preço atual do
  // catálogo, como a API faz) ou o combinado
  Decimal get _precoDosServicos =>
      _servicoTrocado?.preco ?? widget.valorServicos;

  Decimal get _total => _precoDosServicos + _acrescimo - _desconto;

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

  // a escolha do serviço feito de verdade. o combinado fica na lista (com o
  // preço combinado, que é o que vale se ele continuar) mesmo quando saiu
  // do catálogo; escolher ele de volta desfaz a troca
  Future<void> _trocarServico() async {
    final servicos = widget.servicos!;
    final atualId = widget.servicoAtualId!;
    final escolhidoId = _servicoTrocado?.id ?? atualId;
    final atualNaLista = servicos.any((s) => s.id == atualId);

    OpcaoDaFolha<int> opcaoDoAtual() => OpcaoDaFolha(
      valor: atualId,
      texto:
          '${widget.servicoAtualNome} · '
          '${formatarDinheiro(widget.valorServicos)}',
      selecionada: escolhidoId == atualId,
    );

    final escolha = await escolherNaFolha<int>(
      context,
      titulo: 'Trocar o serviço',
      descricao:
          'Pelo que foi feito de verdade, com o preço atual dele. '
          'O registro e os relatórios ficam certos.',
      opcoes: [
        if (!atualNaLista) opcaoDoAtual(),
        for (final s in servicos)
          if (s.id == atualId)
            opcaoDoAtual()
          else
            OpcaoDaFolha(
              valor: s.id,
              texto: '${s.nome} · ${formatarDinheiro(s.preco)}',
              selecionada: escolhidoId == s.id,
            ),
      ],
    );
    if (escolha == null || !mounted) return;
    setState(() {
      _servicoTrocado = escolha == atualId
          ? null
          : servicos.firstWhere((s) => s.id == escolha);
      _acompanharTotal();
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
    final acrescimo = _acrescimo;
    final erro = await widget.onCobrar(
      CobrancaParams(
        id: widget.atendimentoId,
        pagamentos: _pagamentos(),
        desconto: _desconto,
        creditoAplicado: _credito,
        trocoCredito: _trocoComoCredito ? _excedente : _zero,
        acrescimo: acrescimo,
        // o motivo só faz sentido com acréscimo
        acrescimoMotivo: acrescimo > _zero ? _motivoController.text.trim() : '',
        // sem troca a API cobra o combinado
        servicoIds: _servicoTrocado == null ? null : [_servicoTrocado!.id],
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
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final temCredito =
        widget.permiteCredito && widget.creditoDisponivel > _zero;
    final trocado = _servicoTrocado;

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        BrandSpacing.space5,
        BrandSpacing.space4,
        BrandSpacing.space5,
        BrandSpacing.space5,
      ),
      children: [
        Text('Cobrar atendimento', style: textos.titleLarge),
        const SizedBox(height: BrandSpacing.space1),
        Text(
          trocado == null
              ? 'Serviços: ${formatarDinheiro(widget.valorServicos)}'
              : 'Serviço: ${trocado.nome} · ${formatarDinheiro(trocado.preco)}',
          style: textos.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),

        // passou do previsto: a pessoa decide se cobra a mais. é aviso, em
        // azul suave: nada é automático
        if (widget.avisoTempo != null) ...[
          const SizedBox(height: BrandSpacing.space3),
          Container(
            padding: const EdgeInsets.all(BrandSpacing.space3),
            decoration: BoxDecoration(
              color: cores.blueSoft,
              borderRadius: BrandRadius.mdAll,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.timer_outlined, size: 20, color: colors.primary),
                const SizedBox(width: BrandSpacing.space2),
                Expanded(
                  child: Text(widget.avisoTempo!, style: textos.bodyMedium),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: BrandSpacing.space4),

        TextField(
          controller: _descontoController,
          keyboardType: TextInputType.number,
          inputFormatters: const [DinheiroInputFormatter()],
          onChanged: (_) => setState(_acompanharTotal),
          decoration: const InputDecoration(
            labelText: 'Desconto (opcional)',
            prefixText: 'R\$ ',
          ),
        ),

        if (temCredito) ...[
          const SizedBox(height: BrandSpacing.space4),
          TextField(
            controller: _creditoController,
            keyboardType: TextInputType.number,
            inputFormatters: const [DinheiroInputFormatter()],
            onChanged: (_) => setState(_acompanharTotal),
            decoration: InputDecoration(
              labelText: 'Usar crédito do cliente',
              helperText:
                  'Disponível: ${formatarDinheiro(widget.creditoDisponivel)}',
              // o erro esconde o helper: o limite vai junto na mensagem
              errorText: _creditoValido
                  ? null
                  : 'Use até ${formatarDinheiro(widget.creditoDisponivel)}, '
                        'sem passar do total',
              prefixText: 'R\$ ',
            ),
          ),
        ],

        // o que se acerta com o cliente: fechado por padrão, porque o caso
        // comum é cobrar o combinado
        const SizedBox(height: BrandSpacing.space3),
        if (!_ajustando)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _ajustando = true),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Ajustar o combinado'),
            ),
          )
        else
          _combinado(context),

        const SizedBox(height: BrandSpacing.space5),
        Text('Pagamento', style: textos.titleSmall),
        const SizedBox(height: BrandSpacing.space2),
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
                  decoration: const InputDecoration(labelText: 'Forma'),
                ),
              ),
              const SizedBox(width: BrandSpacing.space3),
              Expanded(
                child: TextField(
                  controller: linha.controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [DinheiroInputFormatter()],
                  onChanged: (_) => setState(() => _valorMexido = true),
                  decoration: const InputDecoration(
                    labelText: 'Valor',
                    prefixText: 'R\$ ',
                  ),
                ),
              ),
              if (_linhas.length > 1)
                IconButton(
                  tooltip: 'Remover',
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  onPressed: () => _removerLinha(linha),
                ),
            ],
          ),
          const SizedBox(height: BrandSpacing.space3),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _adicionarLinha,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Outra forma de pagamento'),
          ),
        ),

        // sem comanda o troco só volta em dinheiro
        if (_temTroco && widget.permiteCredito) ...[
          const SizedBox(height: BrandSpacing.space2),
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

        const SizedBox(height: BrandSpacing.space4),
        _Resumo(
          total: _total,
          pago: _pago,
          diferenca: _diferenca,
          temTroco: _temTroco,
        ),

        if (_erro != null) ...[
          const SizedBox(height: BrandSpacing.space3),
          Container(
            padding: const EdgeInsets.all(BrandSpacing.space3),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BrandRadius.mdAll,
              border: Border.all(color: cores.border),
            ),
            child: Text(
              _erro!,
              style: textos.bodyMedium?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ),
        ],

        const SizedBox(height: BrandSpacing.space4),
        FilledButton(
          onPressed: _podeConfirmar ? _confirmar : null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(_enviando ? 'Cobrando...' : 'Confirmar cobrança'),
        ),
      ],
    );
  }

  // a seção aberta: a troca do serviço (quando há lista) e o acréscimo com
  // o motivo. os dois só mudam em comum acordo com o cliente
  Widget _combinado(BuildContext context) {
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final trocado = _servicoTrocado;
    final motivo = _motivoController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Combinado com o cliente', style: textos.titleSmall),
        const SizedBox(height: BrandSpacing.space1),
        Text(
          'Só muda em comum acordo com o cliente. Sem mexer aqui, cobra o '
          'combinado.',
          style: textos.bodySmall?.copyWith(color: cores.inkMuted),
        ),
        if (_podeTrocar) ...[
          const SizedBox(height: BrandSpacing.space2),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.design_services_rounded),
            title: Text(trocado?.nome ?? widget.servicoAtualNome),
            subtitle: Text(
              trocado == null
                  ? 'Serviço combinado'
                  : 'No lugar de ${widget.servicoAtualNome}',
            ),
            trailing: TextButton(
              onPressed: _trocarServico,
              child: const Text('Trocar'),
            ),
          ),
        ],
        const SizedBox(height: BrandSpacing.space3),
        TextField(
          controller: _acrescimoController,
          keyboardType: TextInputType.number,
          inputFormatters: const [DinheiroInputFormatter()],
          onChanged: (_) => setState(_acompanharTotal),
          decoration: const InputDecoration(
            labelText: 'Acréscimo (opcional)',
            prefixText: 'R\$ ',
          ),
        ),
        const SizedBox(height: BrandSpacing.space3),
        TextField(
          controller: _motivoController,
          textCapitalization: TextCapitalization.sentences,
          // o limite é o da API (60)
          inputFormatters: [LengthLimitingTextInputFormatter(60)],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Motivo do acréscimo',
            helperText: 'O cliente vê o motivo no app dele.',
          ),
        ),
        const SizedBox(height: BrandSpacing.space2),
        Wrap(
          spacing: BrandSpacing.space2,
          runSpacing: BrandSpacing.space1,
          children: [
            for (final sugestao in _motivosSugeridos)
              ChoiceChip(
                label: Text(sugestao),
                selected: motivo == sugestao,
                onSelected: (marcado) => setState(() {
                  _motivoController.text = marcado ? sugestao : '';
                }),
              ),
          ],
        ),
      ],
    );
  }
}

// total a cobrar, quanto já está lançado e o que falta, o troco ou o que
// passou sem ter dinheiro para devolver. a cor é o status da soma: success
// quando fecha (exata ou com troco), danger quando trava o confirmar. a
// borda separa o quadro da folha no escuro, onde os dois são o fundo 2
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
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final zero = Decimal.fromInt(0);
    final fecha = diferenca == zero;
    final ok = fecha || temTroco;

    return Container(
      padding: const EdgeInsets.all(BrandSpacing.space3),
      decoration: BoxDecoration(
        color: cores.bg2,
        borderRadius: BrandRadius.mdAll,
        border: Border.all(color: cores.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total a cobrar', style: textos.bodySmall),
                Text(formatarDinheiro(total), style: textos.titleMedium),
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
                style: textos.titleMedium?.copyWith(
                  color: ok ? cores.success : colors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
