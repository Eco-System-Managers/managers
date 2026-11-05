import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/dinheiro.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:managers/features/empresa/domain/entities/nicho.dart';
import 'package:managers/features/empresa/presentation/widgets/nicho_visual.dart';

import '../../domain/entities/servico.dart';

// a escolha de um ou mais serviços do agendamento: no formulário, na ficha
// (antes do atendimento) e na cobrança. o preço de cada um é o que a lista
// traz: quem chama passa o combinado nos que já estão no agendamento. como
// no dropdown de serviço, com mais de um nicho cada um ganha um título.
// devolve os marcados na ordem da lista, ou null quando a folha fecha sem
// confirmar
class EscolherServicosSheet extends StatefulWidget {
  const EscolherServicosSheet({
    super.key,
    required this.titulo,
    required this.servicos,
    required this.marcados,
    this.descricao,
    this.textoConfirmar = 'Confirmar',
  });

  final String titulo;
  final String? descricao;
  final List<Servico> servicos;
  final Set<int> marcados;
  final String textoConfirmar;

  static Future<List<Servico>?> abrir(
    BuildContext context, {
    required String titulo,
    required List<Servico> servicos,
    Set<int> marcados = const {},
    String? descricao,
    String textoConfirmar = 'Confirmar',
  }) {
    return abrirFolha<List<Servico>>(
      context,
      builder: (_) => EscolherServicosSheet(
        titulo: titulo,
        descricao: descricao,
        servicos: servicos,
        marcados: marcados,
        textoConfirmar: textoConfirmar,
      ),
    );
  }

  @override
  State<EscolherServicosSheet> createState() => _EscolherServicosSheetState();
}

class _EscolherServicosSheetState extends State<EscolherServicosSheet> {
  late final Set<int> _marcados = {...widget.marcados};

  // na ordem de exibição dos nichos; serviço sem nicho vai por último
  late final List<Nicho?> _nichos = () {
    int ordem(Nicho? n) => n?.index ?? Nicho.values.length;
    return {for (final s in widget.servicos) s.nicho}.toList()
      ..sort((a, b) => ordem(a).compareTo(ordem(b)));
  }();

  // a lista na ordem em que aparece na tela
  List<Servico> get _naOrdem => [
    for (final nicho in _nichos)
      for (final s in widget.servicos)
        if (s.nicho == nicho) s,
  ];

  List<Servico> get _escolhidos =>
      _naOrdem.where((s) => _marcados.contains(s.id)).toList();

  void _alternar(Servico servico) {
    setState(() {
      if (!_marcados.remove(servico.id)) _marcados.add(servico.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final escolhidos = _escolhidos;
    final duracao = escolhidos.fold(0, (soma, s) => soma + s.duracao);
    final valor = escolhidos.fold(Decimal.zero, (soma, s) => soma + s.preco);
    final porNicho = _nichos.length > 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BrandSpacing.space5,
            BrandSpacing.space4,
            BrandSpacing.space5,
            BrandSpacing.space2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.titulo, style: textos.titleLarge),
              if (widget.descricao != null) ...[
                const SizedBox(height: BrandSpacing.space1),
                Text(
                  widget.descricao!,
                  style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
                ),
              ],
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final nicho in _nichos) ...[
                if (porNicho)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      BrandSpacing.space5,
                      BrandSpacing.space3,
                      BrandSpacing.space5,
                      BrandSpacing.space1,
                    ),
                    child: Text(
                      nicho?.nome ?? 'Outros',
                      style: textos.labelSmall?.copyWith(color: cores.inkMuted),
                    ),
                  ),
                for (final s in widget.servicos)
                  if (s.nicho == nicho)
                    CheckboxListTile(
                      value: _marcados.contains(s.id),
                      onChanged: (_) => _alternar(s),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: BrandSpacing.space3,
                      ),
                      title: Text(s.nome),
                      subtitle: Text(
                        '${formatarDuracao(s.duracao)} · '
                        '${formatarDinheiro(s.preco)}',
                      ),
                    ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BrandSpacing.space5,
            BrandSpacing.space3,
            BrandSpacing.space5,
            BrandSpacing.space4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                escolhidos.isEmpty
                    ? 'Nenhum serviço marcado'
                    : '${resumoDosServicos(escolhidos.length)} · '
                          '${formatarDuracao(duracao)} · '
                          '${formatarDinheiro(valor)}',
                style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
              ),
              const SizedBox(height: BrandSpacing.space3),
              FilledButton(
                onPressed: escolhidos.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(escolhidos),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(widget.textoConfirmar),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// "1 serviço", "3 serviços"
String resumoDosServicos(int quantidade) =>
    quantidade == 1 ? '1 serviço' : '$quantidade serviços';
