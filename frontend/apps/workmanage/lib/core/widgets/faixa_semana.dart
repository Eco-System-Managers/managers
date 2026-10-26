import 'package:flutter/material.dart';
import 'package:managers/core/utils/datas.dart';

// o calendário de cima da agenda e do quadro. fechado, é a semana do dia
// escolhido (segunda a domingo), com uma bolinha nos dias que têm registro;
// aberto, é o mês inteiro. deslizar para o lado troca de semana (ou de mês)
// mantendo o dia da semana (ou do mês); puxar para baixo abre o mês, para
// cima fecha. quem usa guarda se está aberto (a barra de título também abre)
// e busca as bolinhas dos dias na tela (diasDaSemana ou diasDoMes do dia)
class FaixaSemana extends StatefulWidget {
  const FaixaSemana({
    super.key,
    required this.dia,
    required this.hoje,
    required this.temRegistro,
    required this.onSelecionar,
    this.expandido = false,
    this.onExpandir,
  });

  final DateTime dia;
  final DateTime hoje;
  final bool Function(DateTime data) temRegistro;
  final ValueChanged<DateTime> onSelecionar;

  // mês aberto
  final bool expandido;
  final ValueChanged<bool>? onExpandir;

  // a semana (segunda a domingo) que contém o dia
  static List<DateTime> diasDaSemana(DateTime dia) {
    final segunda = DateTime(dia.year, dia.month, dia.day - (dia.weekday - 1));
    return [
      for (var i = 0; i < 7; i++)
        DateTime(segunda.year, segunda.month, segunda.day + i),
    ];
  }

  // as seis semanas que mostram o mês inteiro, começando na segunda
  static List<DateTime> diasDoMes(DateTime dia) {
    final primeiro = DateTime(dia.year, dia.month, 1);
    final inicio = DateTime(
      primeiro.year,
      primeiro.month,
      primeiro.day - (primeiro.weekday - 1),
    );
    return [
      for (var i = 0; i < 42; i++)
        DateTime(inicio.year, inicio.month, inicio.day + i),
    ];
  }

  @override
  State<FaixaSemana> createState() => _FaixaSemanaState();
}

class _FaixaSemanaState extends State<FaixaSemana> {
  // uma segunda-feira bem para trás: as páginas contam semanas (ou meses)
  // a partir dela. em UTC, para a conta de dias não escorregar com horário
  // de verão
  static final _base = DateTime.utc(2000, 1, 3);

  late PageController _semanas;
  late PageController _meses;

  // controllers da vista que saiu da tela: descartados depois do frame, já
  // sem PageView preso neles
  final _descartar = <PageController>[];

  // uma troca de página pelo código (o dia mudou por fora) dispara
  // onPageChanged como se fosse um deslize: a bandeira ignora essas
  bool _animando = false;

  @override
  void initState() {
    super.initState();
    _semanas = PageController(initialPage: _paginaDaSemana(widget.dia));
    _meses = PageController(initialPage: _paginaDoMes(widget.dia));
  }

  @override
  void didUpdateWidget(FaixaSemana antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.expandido != widget.expandido) {
      // a vista que vai aparecer nasce na página do dia atual: um
      // controller solto não guarda em que página ficou
      if (widget.expandido) {
        _descartar.add(_meses);
        _meses = PageController(initialPage: _paginaDoMes(widget.dia));
      } else {
        _descartar.add(_semanas);
        _semanas = PageController(initialPage: _paginaDaSemana(widget.dia));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final c in _descartar) {
          c.dispose();
        }
        _descartar.clear();
      });
    } else if (!mesmoDia(antigo.dia, widget.dia)) {
      _irPara(_semanas, _paginaDaSemana(widget.dia));
      _irPara(_meses, _paginaDoMes(widget.dia));
    }
  }

  @override
  void dispose() {
    _semanas.dispose();
    _meses.dispose();
    for (final c in _descartar) {
      c.dispose();
    }
    super.dispose();
  }

  int _paginaDaSemana(DateTime d) {
    final segunda = FaixaSemana.diasDaSemana(d).first;
    final utc = DateTime.utc(segunda.year, segunda.month, segunda.day);
    return utc.difference(_base).inDays ~/ 7;
  }

  int _paginaDoMes(DateTime d) => (d.year - _base.year) * 12 + d.month - 1;

  DateTime _segundaDaPagina(int pagina) =>
      DateTime(_base.year, _base.month, _base.day + pagina * 7);

  DateTime _primeiroDoMesDaPagina(int pagina) =>
      DateTime(_base.year + pagina ~/ 12, pagina % 12 + 1, 1);

  Future<void> _irPara(PageController controller, int pagina) async {
    if (!controller.hasClients || controller.page?.round() == pagina) return;
    _animando = true;
    // longe (mais de uma página), pular evita passar por cada semana
    final atual = controller.page?.round() ?? pagina;
    if ((atual - pagina).abs() > 1) {
      controller.jumpToPage(pagina);
    } else {
      await controller.animateToPage(
        pagina,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    _animando = false;
  }

  void _deslizouSemana(int pagina) {
    if (_animando) return;
    final segunda = _segundaDaPagina(pagina);
    widget.onSelecionar(
      DateTime(
        segunda.year,
        segunda.month,
        segunda.day + widget.dia.weekday - 1,
      ),
    );
  }

  void _deslizouMes(int pagina) {
    if (_animando) return;
    final primeiro = _primeiroDoMesDaPagina(pagina);
    final ultimoDia = DateTime(primeiro.year, primeiro.month + 1, 0).day;
    widget.onSelecionar(
      DateTime(
        primeiro.year,
        primeiro.month,
        widget.dia.day > ultimoDia ? ultimoDia : widget.dia.day,
      ),
    );
  }

  void _arrastou(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v > 200 && !widget.expandido) widget.onExpandir?.call(true);
    if (v < -200 && widget.expandido) widget.onExpandir?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragEnd: widget.onExpandir == null ? null : _arrastou,
      child: Column(
        children: [
          // os nomes dos dias só no mês: na semana cada dia já tem o seu
          if (widget.expandido)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  for (final nome in nomesCurtosDosDias)
                    Expanded(
                      child: Text(
                        nome,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: widget.expandido ? 6 * 44.0 : 72,
              child: widget.expandido
                  ? PageView.builder(
                      controller: _meses,
                      onPageChanged: _deslizouMes,
                      itemBuilder: (context, pagina) =>
                          _mes(_primeiroDoMesDaPagina(pagina)),
                    )
                  : PageView.builder(
                      controller: _semanas,
                      onPageChanged: _deslizouSemana,
                      itemBuilder: (context, pagina) =>
                          _semana(_segundaDaPagina(pagina)),
                    ),
            ),
          ),
          if (widget.onExpandir != null)
            // a alça: toque ou puxe para abrir e fechar o mês
            InkWell(
              onTap: () => widget.onExpandir!(!widget.expandido),
              child: SizedBox(
                height: 18,
                width: double.infinity,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _semana(DateTime segunda) {
    final dias = FaixaSemana.diasDaSemana(segunda);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final d in dias)
            Expanded(child: _dia(d, comNome: true, doMes: true)),
        ],
      ),
    );
  }

  Widget _mes(DateTime primeiro) {
    final dias = FaixaSemana.diasDoMes(primeiro);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          for (var linha = 0; linha < 6; linha++)
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: _dia(
                        dias[linha * 7 + i],
                        comNome: false,
                        doMes: dias[linha * 7 + i].month == primeiro.month,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dia(DateTime d, {required bool comNome, required bool doMes}) {
    return _Dia(
      data: d,
      selecionado: mesmoDia(d, widget.dia),
      ehHoje: mesmoDia(d, widget.hoje),
      marcado: widget.temRegistro(d),
      comNome: comNome,
      apagado: !doMes,
      onTap: () => widget.onSelecionar(d),
    );
  }
}

class _Dia extends StatelessWidget {
  const _Dia({
    required this.data,
    required this.selecionado,
    required this.ehHoje,
    required this.marcado,
    required this.comNome,
    required this.apagado,
    required this.onTap,
  });

  final DateTime data;
  final bool selecionado;
  final bool ehHoje;
  final bool marcado;

  // o nome do dia em cima (só na semana)
  final bool comNome;

  // de outro mês, na grade do mês
  final bool apagado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final corTexto = selecionado
        ? colors.onPrimary
        : apagado
        ? colors.outline
        : ehHoje
        ? colors.primary
        : colors.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: EdgeInsets.symmetric(vertical: comNome ? 6 : 2),
        decoration: BoxDecoration(
          color: selecionado ? colors.primary : null,
          borderRadius: BorderRadius.circular(12),
          border: ehHoje && !selecionado
              ? Border.all(color: colors.primary.withValues(alpha: 0.5))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (comNome) ...[
              Text(
                nomeCurtoDoDia(data),
                style: TextStyle(fontSize: 11, color: corTexto),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              '${data.day}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: selecionado || ehHoje
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: corTexto,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: marcado
                    ? (selecionado ? colors.onPrimary : colors.primary)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
