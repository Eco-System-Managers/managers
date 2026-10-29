import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';

import '../../domain/entities/agendamento.dart';
import '../../domain/entities/bloqueio.dart';
import 'grade_do_dia_layout.dart';
import 'status_agendamento_chip.dart';

// a grade de horários de um dia: a coluna das horas à esquerda, uma linha a
// cada passo, os agendamentos desenhados na hora e com a altura da duração,
// a linha do "agora" (azul, o estado atual) quando é hoje, e os bloqueios
// como faixas neutras por baixo dos agendamentos. tocar num espaço vazio
// devolve a hora; tocar num bloqueio, o bloqueio
class GradeDoDia extends StatefulWidget {
  const GradeDoDia({
    super.key,
    required this.inicio,
    required this.fim,
    required this.passo,
    required this.blocos,
    required this.agora,
    required this.onTapVazio,
    required this.onTapAgendamento,
    this.faixas = const [],
    this.onTapBloqueio,
    this.nomeNoBloqueio = false,
  });

  // o trecho do dia, em minutos desde a meia-noite
  final int inicio;
  final int fim;
  final int passo;
  final List<BlocoDaGrade> blocos;

  // null quando o dia aberto não é hoje
  final DateTime? agora;
  final ValueChanged<Hora> onTapVazio;
  final ValueChanged<Agendamento> onTapAgendamento;
  final List<FaixaBloqueada> faixas;
  final ValueChanged<Bloqueio>? onTapBloqueio;

  // com a agenda de todos aberta, a faixa diz de quem é o bloqueio
  final bool nomeNoBloqueio;

  // 30 minutos = 54 px: cabe o nome do cliente num bloco de meia hora
  static const pixelsPorMinuto = 1.8;
  static const larguraDasHoras = 56.0;

  @override
  State<GradeDoDia> createState() => _GradeDoDiaState();
}

class _GradeDoDiaState extends State<GradeDoDia> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rolarParaAgora());
  }

  @override
  void didUpdateWidget(GradeDoDia antigo) {
    super.didUpdateWidget(antigo);
    // trocou o dia: volta ao topo, ou ao agora quando voltou para hoje
    if (antigo.inicio != widget.inicio ||
        (antigo.agora == null) != (widget.agora == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _rolarParaAgora());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _rolarParaAgora() {
    if (!_scroll.hasClients) return;
    final agora = widget.agora;
    final alvo = agora == null
        ? 0.0
        : ((minutosDoDia(agora) - widget.inicio) * GradeDoDia.pixelsPorMinuto -
                  120)
              .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(alvo);
  }

  double _y(int minuto) =>
      (minuto - widget.inicio) * GradeDoDia.pixelsPorMinuto;

  // o pedaço da faixa que cai no trecho mostrado; null quando fica todo fora
  (int, int)? _recorte(FaixaBloqueada faixa) {
    final de = faixa.inicio < widget.inicio ? widget.inicio : faixa.inicio;
    final ate = faixa.fim > widget.fim ? widget.fim : faixa.fim;
    return ate > de ? (de, ate) : null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cores = BrandColors.of(context);
    final altura = _y(widget.fim);
    final agora = widget.agora;
    final minutoAgora = agora == null ? null : minutosDoDia(agora);
    final mostraAgora =
        minutoAgora != null &&
        minutoAgora >= widget.inicio &&
        minutoAgora <= widget.fim;

    return SingleChildScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: BrandSpacing.space7),
      child: SizedBox(
        height: altura + 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: GradeDoDia.larguraDasHoras,
              child: Stack(
                children: [
                  for (var m = widget.inicio; m <= widget.fim; m += 60)
                    Positioned(
                      top: _y(m) - 8,
                      right: BrandSpacing.space2,
                      child: Text(
                        formatarHora((hora: m ~/ 60, minuto: 0)),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final largura = constraints.maxWidth;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // o fundo com as linhas, que recebe o toque no vazio
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) {
                            final minuto = minutoTocado(
                              inicioDaGrade: widget.inicio,
                              minutosDesdeOTopo:
                                  (d.localPosition.dy /
                                          GradeDoDia.pixelsPorMinuto)
                                      .floor(),
                              passo: widget.passo,
                            );
                            if (minuto >= widget.fim) return;
                            widget.onTapVazio((
                              hora: minuto ~/ 60,
                              minuto: minuto % 60,
                            ));
                          },
                          child: CustomPaint(
                            painter: _LinhasPainter(
                              inicio: widget.inicio,
                              fim: widget.fim,
                              passo: widget.passo,
                              pixelsPorMinuto: GradeDoDia.pixelsPorMinuto,
                              corHora: cores.border,
                              // a linha do passo é mais clara que a da hora
                              corPasso: cores.bg2,
                            ),
                          ),
                        ),
                      ),
                      for (final faixa in widget.faixas)
                        if (_recorte(faixa) case (final de, final ate))
                          Positioned(
                            top: _y(de),
                            height: _y(ate) - _y(de),
                            left: 0,
                            right: 0,
                            child: _Faixa(
                              bloqueio: faixa.bloqueio,
                              comNome: widget.nomeNoBloqueio,
                              onTap: () =>
                                  widget.onTapBloqueio?.call(faixa.bloqueio),
                            ),
                          ),
                      for (final bloco in widget.blocos)
                        Positioned(
                          top: _y(bloco.inicio),
                          height: (_y(bloco.fim) - _y(bloco.inicio)).clamp(
                            duracaoMinimaDoBloco * GradeDoDia.pixelsPorMinuto,
                            double.infinity,
                          ),
                          // um respiro de space1 de cada lado do bloco
                          left:
                              largura * bloco.coluna / bloco.colunas +
                              BrandSpacing.space1,
                          width: largura / bloco.colunas - BrandSpacing.space2,
                          child: _Bloco(
                            bloco: bloco,
                            onTap: () =>
                                widget.onTapAgendamento(bloco.agendamento),
                          ),
                        ),
                      if (mostraAgora)
                        Positioned(
                          top: _y(minutoAgora) - 1,
                          left: -6,
                          right: 0,
                          child: IgnorePointer(
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.primary,
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 2,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// um agendamento na grade: o fundo de destaque, a barra da cor do status,
// hora, cliente e serviços. o texto fica todo em ink sobre o blueSoft
class _Bloco extends StatelessWidget {
  const _Bloco({required this.bloco, required this.onTap});

  final BlocoDaGrade bloco;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final a = bloco.agendamento;
    final altura = (bloco.fim - bloco.inicio) * GradeDoDia.pixelsPorMinuto;
    final servicos = a.servicos.map((s) => s.nome).join(', ');
    final detalhe = textos.bodySmall?.copyWith(color: cores.ink);

    return Material(
      color: cores.blueSoft,
      borderRadius: BrandRadius.smAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: BrandRadius.smAll,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BrandRadius.smAll,
            border: Border(
              left: BorderSide(color: a.status.cor(cores), width: 3),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            BrandSpacing.space2,
            BrandSpacing.space1,
            BrandSpacing.space1,
            BrandSpacing.space1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatarHora(horaDe(a.dataHora))} · ${a.clienteNome}',
                style: textos.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (altura >= 44 && servicos.isNotEmpty)
                Text(
                  servicos,
                  style: detalhe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (altura >= 64 && (a.colaboradorNome?.isNotEmpty ?? false))
                Text(
                  a.colaboradorNome!,
                  style: detalhe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// um bloqueio na grade: a faixa neutra de ponta a ponta, com a borda
// apagada à esquerda e o motivo (ou "Bloqueado") em inkMuted
class _Faixa extends StatelessWidget {
  const _Faixa({
    required this.bloqueio,
    required this.comNome,
    required this.onTap,
  });

  final Bloqueio bloqueio;
  final bool comNome;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final titulo = bloqueio.motivo.isEmpty ? 'Bloqueado' : bloqueio.motivo;
    final texto = comNome && bloqueio.colaboradorNome.isNotEmpty
        ? '$titulo · ${bloqueio.colaboradorNome}'
        : titulo;

    return Material(
      color: cores.bg2,
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.topLeft,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: cores.inkMuted, width: 3)),
          ),
          padding: const EdgeInsets.fromLTRB(
            BrandSpacing.space2,
            BrandSpacing.space1,
            BrandSpacing.space1,
            0,
          ),
          child: Row(
            children: [
              Icon(Icons.block_rounded, size: 14, color: cores.inkMuted),
              const SizedBox(width: BrandSpacing.space1),
              Expanded(
                child: Text(
                  texto,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: cores.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhasPainter extends CustomPainter {
  const _LinhasPainter({
    required this.inicio,
    required this.fim,
    required this.passo,
    required this.pixelsPorMinuto,
    required this.corHora,
    required this.corPasso,
  });

  final int inicio;
  final int fim;
  final int passo;
  final double pixelsPorMinuto;
  final Color corHora;
  final Color corPasso;

  @override
  void paint(Canvas canvas, Size size) {
    final hora = Paint()
      ..color = corHora
      ..strokeWidth = 1;
    final linha = Paint()
      ..color = corPasso
      ..strokeWidth = 1;
    for (var m = inicio; m <= fim; m += passo) {
      final y = (m - inicio) * pixelsPorMinuto;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        m % 60 == 0 ? hora : linha,
      );
    }
  }

  @override
  bool shouldRepaint(_LinhasPainter antigo) =>
      antigo.inicio != inicio ||
      antigo.fim != fim ||
      antigo.passo != passo ||
      antigo.corHora != corHora ||
      antigo.corPasso != corPasso;
}
