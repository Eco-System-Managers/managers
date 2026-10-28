import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:validatorless/validatorless.dart';

import 'package:managers/features/empresa/domain/entities/empresa_config.dart';
import 'package:managers/features/empresa/domain/entities/nicho.dart';

import '../providers/wizard_provider.dart';

import 'package:managers/features/empresa/presentation/widgets/nicho_visual.dart';

// step 2: escolher o ramo do negócio. tocar num card só marca; quem salva
// é o "Próximo" (o nicho decide o tipo de agenda no backend). no outro, o
// dono descreve o ramo e diz como atende, e é isso que decide o modo
class NichoStep extends StatefulWidget {
  const NichoStep({super.key, required this.provider});

  final WizardProvider provider;

  @override
  State<NichoStep> createState() => _NichoStepState();
}

class _NichoStepState extends State<NichoStep> {
  // o required do Validatorless aceita só espaços; isto exige um caractere
  static final _notBlank = RegExp(r'\S');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descricaoController;

  WizardProvider get _provider => widget.provider;

  @override
  void initState() {
    super.initState();
    _descricaoController = TextEditingController(
      text: _provider.config.nichoDescricao,
    );
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _proximo() async {
    if (!_formKey.currentState!.validate()) return;
    await _provider.salvarNicho(descricao: _descricaoController.text);
  }

  @override
  Widget build(BuildContext context) {
    final selecionado = _provider.config.nicho;
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Escolha o que melhor descreve o seu negócio.',
            style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
          ),

          const SizedBox(height: BrandSpacing.space4),

          // 3 colunas no celular, 4 no tablet
          LayoutBuilder(
            builder: (context, constraints) {
              final colunas = constraints.maxWidth >= 560 ? 4 : 3;

              return GridView.count(
                crossAxisCount: colunas,
                mainAxisSpacing: BrandSpacing.space3,
                crossAxisSpacing: BrandSpacing.space3,
                childAspectRatio: 0.9,
                // a rolagem é da página: a grade só ocupa a altura dela
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // o outro fica fora do MVP: o backend já aceita, o app só
                  // não oferece. tirar este filtro é o bastante para voltar
                  for (final nicho in Nicho.values)
                    if (nicho != Nicho.outro)
                      _NichoCard(
                        nicho: nicho,
                        selecionado: nicho == selecionado,
                        onTap: _provider.isLoading
                            ? null
                            : () => _provider.escolherNicho(nicho),
                      ),
                ],
              );
            },
          ),

          if (selecionado == Nicho.outro) ...[
            const SizedBox(height: BrandSpacing.space5),
            TextFormField(
              controller: _descricaoController,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              validator: Validatorless.regex(
                _notBlank,
                'Descreva o seu negócio',
              ),
              decoration: const InputDecoration(
                labelText: 'Qual é o seu negócio?',
                hintText: 'Ex.: oficina mecânica, psicologia',
                prefixIcon: Icon(Icons.storefront_rounded),
              ),
            ),
            const SizedBox(height: BrandSpacing.space2),
            Text('Como você atende?', style: textos.titleSmall),
            const SizedBox(height: BrandSpacing.space2),
            for (final modo in _Modo.values)
              Padding(
                padding: const EdgeInsets.only(bottom: BrandSpacing.space2),
                child: _ModoOpcao(
                  modo: modo,
                  selecionado: modo == _Modo.de(_provider.config),
                  onTap: _provider.isLoading
                      ? null
                      : () => _provider.escolherModo(
                          modo.tipoAgenda,
                          tipoObjeto: modo.tipoObjeto,
                        ),
                ),
              ),
          ],

          const SizedBox(height: BrandSpacing.space5),

          FilledButton(
            // sem nicho escolhido não há o que salvar
            onPressed: _provider.isLoading || selecionado == null
                ? null
                : _proximo,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Próximo'),
          ),
        ],
      ),
    );
  }
}

// as respostas de "como você atende?". o kanban se divide em dois porque o
// card do quadro é sempre um objeto: quem recebe veículo não recebe pet
enum _Modo {
  horario(
    TipoAgenda.horario,
    null,
    'Com horário marcado',
    'O cliente agenda um horário com você ou com a equipe',
    Icons.event_rounded,
  ),
  veiculo(
    TipoAgenda.kanban,
    TipoObjeto.veiculo,
    'Recebo veículos',
    'O cliente deixa o veículo e busca quando ficar pronto',
    Icons.directions_car_rounded,
  ),
  pet(
    TipoAgenda.kanban,
    TipoObjeto.pet,
    'Recebo pets',
    'O cliente deixa o pet e busca quando ficar pronto',
    Icons.pets_rounded,
  );

  const _Modo(
    this.tipoAgenda,
    this.tipoObjeto,
    this.titulo,
    this.descricao,
    this.icone,
  );

  final TipoAgenda tipoAgenda;
  final TipoObjeto? tipoObjeto;
  final String titulo;
  final String descricao;
  final IconData icone;

  // a resposta marcada, a partir da config. kanban sem objeto ainda não
  // tem resposta
  static _Modo? de(EmpresaConfig config) {
    if (config.tipoAgenda == TipoAgenda.horario) return _Modo.horario;
    return switch (config.tipoObjeto) {
      TipoObjeto.veiculo => _Modo.veiculo,
      TipoObjeto.pet => _Modo.pet,
      null => null,
    };
  }
}

class _ModoOpcao extends StatelessWidget {
  const _ModoOpcao({
    required this.modo,
    required this.selecionado,
    required this.onTap,
  });

  final _Modo modo;
  final bool selecionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cores = BrandColors.of(context);

    // a opção escolhida é o azul suave com contorno azul (estado ativo); as
    // outras, o fundo da página com a borda fina
    return Material(
      color: selecionado ? cores.blueSoft : cores.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BrandRadius.mdAll,
        side: BorderSide(
          color: selecionado ? colors.primary : cores.border,
          width: selecionado ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(modo.icone),
        title: Text(modo.titulo),
        subtitle: Text(modo.descricao),
        trailing: selecionado
            ? Icon(Icons.check_circle_rounded, color: colors.primary)
            : null,
        iconColor: selecionado ? cores.ink : null,
      ),
    );
  }
}

class _NichoCard extends StatelessWidget {
  const _NichoCard({
    required this.nicho,
    required this.selecionado,
    required this.onTap,
  });

  final Nicho nicho;
  final bool selecionado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cores = BrandColors.of(context);

    // o nicho escolhido é o azul suave com contorno azul; o conteúdo fica
    // em ink nos dois estados, e o escolhido se marca pelo fundo e pela borda
    return Material(
      color: selecionado ? cores.blueSoft : cores.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BrandRadius.mdAll,
        side: BorderSide(
          color: selecionado ? colors.primary : cores.border,
          width: selecionado ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(BrandSpacing.space2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(nicho.icone, size: 32, color: cores.ink),
              const SizedBox(height: BrandSpacing.space2),
              Text(
                nicho.nome,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
