import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/config/env.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/selo_de_status.dart';
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../assinatura_provider.dart';
import '../../domain/entities/assinatura.dart';
import '../../domain/entities/oferta_de_plano.dart';
import '../providers/assinatura_provider.dart';

// a assinatura do negócio: o status, os planos da loja (Pro, Business,
// Enterprise; mensal, semestral ou anual), a compra pela janela da loja,
// restaurar, gerenciar na loja e o histórico de cobranças. é para cá que o
// 402 traz quem está bloqueado. onde não dá para assinar (semVenda: a fase
// de testes ou a loja sem configurar) a tela vira "Acesso" e mostra só o
// aviso, com sair e excluir a conta
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

  // o aviso de sucesso sai no fim da ação, nunca no build
  Future<void> _depoisDe(Future<void> Function() acao) async {
    await acao();
    if (!mounted) return;
    final aviso = _provider.aviso;
    if (aviso != null) {
      _avisar(aviso);
      _provider.avisoMostrado();
    }
  }

  Future<void> _abrir(String link) async {
    final abriu = await launchUrl(
      Uri.parse(link),
      mode: LaunchMode.externalApplication,
    );
    if (!abriu && mounted) _avisar('Não foi possível abrir o link.');
  }

  // a tela de assinaturas da loja, onde se cancela ou troca o cartão
  Future<void> _gerenciar() async {
    final link = await _provider.linkDeGerenciar();
    if (!mounted) return;
    await _abrir(
      link ??
          (defaultTargetPlatform == TargetPlatform.iOS
              ? 'https://apps.apple.com/account/subscriptions'
              : 'https://play.google.com/store/account/subscriptions'),
    );
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(assinaturaProvider);
    final negocio = ref.watch(negocioAtualProvider);

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(provider.semVenda ? 'Acesso' : 'Assinatura'),
        ),
        body: _corpo(provider, negocio.ehProprietario),
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
    if (provider.semVenda) return _corpoSemVenda(provider);

    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final assinatura = provider.assinatura;
    final bloqueio = provider.mensagemDeBloqueio;
    final daLoja =
        assinatura != null &&
        !assinatura.vitalicia &&
        (assinatura.status == StatusAssinatura.ativa ||
            assinatura.status == StatusAssinatura.cancelada);

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
            const _Aviso(
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
            if (provider.mostraPlanos) ..._planos(provider),
            if (provider.lojaSemPlanos) ...[
              const _Aviso(
                texto: 'Não foi possível carregar os planos da loja agora.',
                icone: Icons.cloud_off_rounded,
                erro: false,
              ),
              TextButton(
                onPressed: provider.isLoading ? null : provider.carregar,
                child: const Text('Tentar de novo'),
              ),
            ],
            if (daLoja) ...[
              const SizedBox(height: BrandSpacing.space3),
              OutlinedButton.icon(
                onPressed: _gerenciar,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Gerenciar ou cancelar na loja'),
              ),
            ],
          ],

          if (provider.bloqueada) ..._saidas(provider),

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

  // a escolha do plano (só os que comportam a equipe) e do período, o
  // botão de assinar e o que a Apple pede junto: renovação automática,
  // termos, privacidade e restaurar
  List<Widget> _planos(AssinaturaProvider provider) {
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final escolhida = provider.ofertaEscolhida;
    final assinatura = provider.assinatura;

    return [
      Text(
        provider.assinaturaAtiva ? 'Trocar de plano' : 'Escolha o plano',
        style: textos.titleLarge,
      ),
      if (assinatura != null && assinatura.equipeAtiva > 0) ...[
        const SizedBox(height: BrandSpacing.space1),
        Text(
          'Sua equipe tem ${assinatura.equipeAtiva} '
          '${assinatura.equipeAtiva == 1 ? 'pessoa' : 'pessoas'}: aparecem '
          'os planos que comportam ela.',
          style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
        ),
      ],
      const SizedBox(height: BrandSpacing.space3),
      for (final plano in provider.planosDisponiveis) ...[
        _Escolha(
          titulo: plano.nome,
          subtitulo: plano.descricao,
          selecionado: provider.planoEscolhido == plano,
          selo: assinatura?.plano == plano && provider.assinaturaAtiva
              ? 'Seu plano'
              : null,
          onTap: () => provider.escolherPlano(plano),
        ),
        const SizedBox(height: BrandSpacing.space2),
      ],

      const SizedBox(height: BrandSpacing.space3),
      Text('Período', style: textos.titleMedium),
      const SizedBox(height: BrandSpacing.space2),
      for (final oferta in provider.ofertasDoPlano) ...[
        _Escolha(
          titulo: oferta.periodo.nome,
          subtitulo: switch (oferta) {
            OfertaDePlano(periodo: PeriodoDoPlano.mensal) =>
              '${oferta.precoTexto} por mês',
            OfertaDePlano(:final String precoPorMesTexto) =>
              '${oferta.precoTexto} · $precoPorMesTexto por mês',
            _ => oferta.precoTexto,
          },
          selecionado: provider.periodoEscolhido == oferta.periodo,
          selo: switch (provider.descontoDe(oferta)) {
            0 => null,
            final desconto when oferta.periodo == PeriodoDoPlano.anual =>
              'Mais vantajoso · -$desconto%',
            final desconto => '-$desconto%',
          },
          onTap: () => provider.escolherPeriodo(oferta.periodo),
        ),
        const SizedBox(height: BrandSpacing.space2),
      ],

      const SizedBox(height: BrandSpacing.space3),
      FilledButton(
        onPressed: provider.isLoading || escolhida == null
            ? null
            : () => _depoisDe(provider.comprar),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(
          escolhida == null
              ? 'Escolha o período'
              : 'Assinar ${escolhida.plano.nome} '
                    '${escolhida.periodo.nome.toLowerCase()}',
        ),
      ),
      const SizedBox(height: BrandSpacing.space3),
      Text(
        'A assinatura renova automaticamente pelo mesmo valor ao fim de cada '
        'período, a menos que seja cancelada até 24 horas antes. A cobrança é '
        'feita na sua conta da '
        '${defaultTargetPlatform == TargetPlatform.iOS ? 'App Store' : 'Google Play'}, '
        'e você cancela quando quiser nos ajustes da loja.',
        style: textos.bodySmall?.copyWith(color: cores.inkMuted),
      ),
      Wrap(
        alignment: WrapAlignment.center,
        children: [
          TextButton(
            onPressed: () => _abrir(Env.linkTermos),
            child: const Text('Termos de uso'),
          ),
          TextButton(
            onPressed: () => _abrir(Env.linkPrivacidade),
            child: const Text('Privacidade'),
          ),
          TextButton(
            onPressed: provider.isLoading
                ? null
                : () => _depoisDe(provider.restaurar),
            child: const Text('Restaurar compras'),
          ),
        ],
      ),
    ];
  }

  // sem venda não se fala de assinatura: nem plano, nem cobranças, nem
  // "Em breve". bloqueado, o aviso neutro e as saídas; em dia, só que o
  // acesso está liberado
  Widget _corpoSemVenda(AssinaturaProvider provider) {
    final bloqueio = provider.mensagemDeBloqueio;
    return ListView(
      padding: const EdgeInsets.all(BrandSpacing.space4),
      children: [
        if (bloqueio != null) ...[
          _Aviso(
            texto: bloqueio,
            icone: Icons.lock_outline_rounded,
            erro: true,
          ),
          ..._saidas(provider),
        ] else
          const _Aviso(
            texto: 'O acesso deste negócio está liberado.',
            icone: Icons.check_circle_outline_rounded,
            erro: false,
          ),
      ],
    );
  }

  // bloqueado, o router prende a pessoa nesta tela: daqui ela ainda sai do
  // app ou exclui a conta (as lojas exigem que dê para excluir)
  List<Widget> _saidas(AssinaturaProvider provider) {
    final cores = BrandColors.of(context);
    return [
      const SizedBox(height: BrandSpacing.space5),
      OutlinedButton.icon(
        onPressed: provider.saindo ? null : provider.sair,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sair'),
      ),
      TextButton(
        onPressed: () => context.push('/mais/excluir-conta'),
        style: TextButton.styleFrom(foregroundColor: cores.inkMuted),
        child: const Text('Excluir conta'),
      ),
    ];
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

// uma opção de escolha única (plano ou período): borda clara, e a primária
// com o fundo do selecionado quando escolhida
class _Escolha extends StatelessWidget {
  const _Escolha({
    required this.titulo,
    required this.subtitulo,
    required this.selecionado,
    required this.onTap,
    this.selo,
  });

  final String titulo;
  final String subtitulo;
  final bool selecionado;
  final VoidCallback onTap;
  final String? selo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    return Material(
      color: selecionado ? colors.secondaryContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BrandRadius.mdAll,
        side: BorderSide(
          color: selecionado ? colors.primary : colors.outline,
          width: selecionado ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BrandRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.all(BrandSpacing.space3),
          child: Row(
            children: [
              Icon(
                selecionado
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selecionado ? colors.primary : cores.inkMuted,
              ),
              const SizedBox(width: BrandSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: textos.titleMedium),
                    Text(
                      subtitulo,
                      style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
                    ),
                  ],
                ),
              ),
              if (selo != null) SeloDeStatus(texto: selo!, cor: cores.success),
            ],
          ),
        ),
      ),
    );
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
            if (a.vitalicia)
              const _Linha(rotulo: 'Acesso', valor: 'Vitalício')
            else ...[
              _Linha(rotulo: 'Início', valor: formatarData(a.inicio)),
              if (a.status == StatusAssinatura.trial && a.trialFim != null)
                _Linha(rotulo: 'Teste até', valor: formatarData(a.trialFim!))
              else
                _Linha(
                  rotulo: a.status == StatusAssinatura.cancelada
                      ? 'Acesso até'
                      : 'Renova em',
                  valor: formatarData(a.proximoVencimento),
                ),
            ],
            _Linha(
              rotulo: 'Equipe',
              valor: a.limiteEquipe == 0
                  ? 'Só o dono'
                  : '${a.equipeAtiva} de ${a.limiteEquipe}',
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
