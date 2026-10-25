import 'package:flutter/material.dart';
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

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Escolha o que melhor descreve o seu negócio.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 16),

          // 3 colunas no celular, 4 no tablet
          LayoutBuilder(
            builder: (context, constraints) {
              final colunas = constraints.maxWidth >= 560 ? 4 : 3;

              return GridView.count(
                crossAxisCount: colunas,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
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
            const SizedBox(height: 24),
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
                prefixIcon: Icon(Icons.storefront_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Como você atende?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final modo in _Modo.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
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

          const SizedBox(height: 24),

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
    Icons.event_outlined,
  ),
  veiculo(
    TipoAgenda.kanban,
    TipoObjeto.veiculo,
    'Recebo veículos',
    'O cliente deixa o veículo e busca quando ficar pronto',
    Icons.directions_car_outlined,
  ),
  pet(
    TipoAgenda.kanban,
    TipoObjeto.pet,
    'Recebo pets',
    'O cliente deixa o pet e busca quando ficar pronto',
    Icons.pets_outlined,
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

    return Material(
      color: selecionado ? colors.primaryContainer : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selecionado ? colors.primary : colors.outlineVariant,
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
            ? Icon(Icons.check_circle, color: colors.primary)
            : null,
        textColor: selecionado ? colors.onPrimaryContainer : null,
        iconColor: selecionado ? colors.onPrimaryContainer : null,
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
    final corConteudo = selecionado
        ? colors.onPrimaryContainer
        : colors.onSurface;

    return Material(
      color: selecionado ? colors.primaryContainer : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selecionado ? colors.primary : colors.outlineVariant,
          width: selecionado ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(nicho.icone, size: 32, color: corConteudo),
              const SizedBox(height: 8),
              Text(
                nicho.nome,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: corConteudo,
                  fontWeight: selecionado ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
