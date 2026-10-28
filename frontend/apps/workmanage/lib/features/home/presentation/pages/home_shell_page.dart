import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/features/agenda/agenda_provider.dart';
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:managers/features/kanban/kanban_provider.dart';

// a casca do app: a barra inferior flutuante com as quatro abas (Início,
// Agenda/Quadro, Clientes e Mais), cada uma com a própria pilha
// (StatefulShellRoute). antes de mostrar as abas, carrega o negócio atual:
// é ele que diz o modo de agenda e o papel de quem entrou
class HomeShellPage extends ConsumerStatefulWidget {
  const HomeShellPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage> {
  @override
  void initState() {
    super.initState();
    // depois do primeiro build, com o provider já vivo pelo watch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(negocioAtualProvider).carregar();
    });
  }

  // a aba da agenda (ou do quadro) fica viva enquanto a pessoa mexe nas
  // outras: ao voltar para ela, o dia vem da API de novo, com os horários
  // de funcionamento que podem ter mudado em Mais
  void _selecionarAba(int index) {
    final shell = widget.navigationShell;
    final voltouParaAgenda = index == 1 && index != shell.currentIndex;
    // tocar na aba atual volta para o começo da pilha dela
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
    if (voltouParaAgenda) {
      if (ref.read(negocioAtualProvider).isKanban) {
        ref.read(quadroProvider).recarregar();
      } else {
        ref.read(agendaDiaProvider).recarregar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final negocio = ref.watch(negocioAtualProvider);
    final shell = widget.navigationShell;

    return ListenableBuilder(
      listenable: negocio,
      builder: (context, _) {
        if (!negocio.carregado) {
          final erro = negocio.erro;
          if (erro != null) {
            return Scaffold(
              body: EstadoErro(
                mensagem: erro.message,
                onTentarDeNovo: () => negocio.carregar(forcar: true),
              ),
            );
          }
          return const Scaffold(body: Carregando());
        }

        return Scaffold(
          // o conteúdo das abas termina acima da barra, não por baixo dela;
          // a sombra branca encostada nela é de cada aba (comSombraEmBaixo)
          body: shell,
          bottomNavigationBar: _BarraFlutuante(
            indice: shell.currentIndex,
            onSelecionar: _selecionarAba,
            abas: [
              const _Aba(icone: Icons.grid_view_rounded, rotulo: 'Início'),
              _Aba(
                icone: negocio.isKanban
                    ? Icons.view_kanban_rounded
                    : Icons.calendar_month_rounded,
                // o rótulo segue o modo de agenda do negócio
                rotulo: negocio.isKanban ? 'Quadro' : 'Agenda',
              ),
              const _Aba(
                icone: Icons.people_outline_rounded,
                rotulo: 'Clientes',
              ),
              const _Aba(icone: Icons.menu_rounded, rotulo: 'Mais'),
            ],
          ),
        );
      },
    );
  }
}

class _Aba {
  const _Aba({required this.icone, required this.rotulo});

  final IconData icone;
  final String rotulo;
}

// a barra inferior: um cartão solto sobre o conteúdo, com a única sombra do
// Design System e margem das bordas; o fundo da página no claro e o fundo 2
// com borda no escuro, em radius-lg. a aba atual fica na cor primária, as
// outras em cinza. a margem de baixo soma a área segura do sistema, então
// ela nunca encosta nos botões do Android
class _BarraFlutuante extends StatelessWidget {
  const _BarraFlutuante({
    required this.indice,
    required this.onSelecionar,
    required this.abas,
  });

  final int indice;
  final ValueChanged<int> onSelecionar;
  final List<_Aba> abas;

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final claro = Theme.of(context).brightness == Brightness.light;
    final areaSegura = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        BrandSpacing.space4,
        0,
        BrandSpacing.space4,
        BrandSpacing.space3 + areaSegura,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: claro ? cores.bg : cores.bg2,
          borderRadius: BrandRadius.lgAll,
          // no escuro o fundo 2 quase se confunde com a página: a borda
          // desenha o contorno
          border: claro ? null : Border.all(color: cores.border),
          boxShadow: BrandShadows.card(context),
        ),
        // o Material transparente é só para o toque das abas, recortado no
        // mesmo raio
        child: Material(
          color: Colors.transparent,
          borderRadius: BrandRadius.lgAll,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            // a altura da barra é medida do componente
            height: 68,
            child: Row(
              children: [
                for (var i = 0; i < abas.length; i++)
                  Expanded(
                    child: _ItemDaBarra(
                      aba: abas[i],
                      selecionado: i == indice,
                      onTap: () => onSelecionar(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemDaBarra extends StatelessWidget {
  const _ItemDaBarra({
    required this.aba,
    required this.selecionado,
    required this.onTap,
  });

  final _Aba aba;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    // a aba atual é o estado ativo (azul); as outras, o cinza do texto
    // secundário. o rótulo é label-medium nos dois casos
    final cor = selecionado ? colors.primary : colors.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Semantics(
        selected: selecionado,
        button: true,
        label: aba.rotulo,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(aba.icone, color: cor, size: 24),
            const SizedBox(height: BrandSpacing.space1),
            Text(aba.rotulo, style: textos.labelMedium?.copyWith(color: cor)),
          ],
        ),
      ),
    );
  }
}
