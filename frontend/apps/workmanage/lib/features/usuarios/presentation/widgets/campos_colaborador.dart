import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:validatorless/validatorless.dart';

import '../../domain/entities/colaborador.dart';
import '../../domain/params/equipe_params.dart';

// os campos de alguém da equipe, iguais no cadastro e na ficha: nome,
// função, vínculo e, conforme o vínculo, a comissão (parceiro) ou a flag de
// cobrar (colaborador). quem usa guarda os controllers e monta os dados
class CamposColaborador extends StatelessWidget {
  const CamposColaborador({
    super.key,
    required this.nomeController,
    required this.funcaoController,
    required this.comissaoController,
    required this.tipo,
    required this.podeCobrar,
    required this.onTipo,
    required this.onPodeCobrar,
    required this.erroDoCampo,
    required this.limparErroDoCampo,
    this.habilitado = true,
    this.temAcesso = false,
  });

  // o required do Validatorless aceita só espaços; isto exige um caractere
  static final _notBlank = RegExp(r'\S');

  final TextEditingController nomeController;
  final TextEditingController funcaoController;
  final TextEditingController comissaoController;
  final VinculoColaborador tipo;
  final bool podeCobrar;
  final ValueChanged<VinculoColaborador> onTipo;
  final ValueChanged<bool> onPodeCobrar;
  final String? Function(String campo) erroDoCampo;
  final ValueChanged<String> limparErroDoCampo;
  final bool habilitado;

  // registrar cobrança é coisa de quem entra no app: sem acesso (nem
  // convite a caminho) a permissão não aparece
  final bool temAcesso;

  // os dados a partir dos campos, já validados
  static DadosColaborador dados({
    required TextEditingController nome,
    required TextEditingController funcao,
    required TextEditingController comissao,
    required VinculoColaborador tipo,
    required bool podeCobrar,
  }) {
    final pct = comissao.text.trim().replaceAll(',', '.');
    return DadosColaborador(
      nome: nome.text.trim(),
      funcao: funcao.text.trim(),
      tipo: tipo,
      comissaoPercentual: tipo == VinculoColaborador.parceiro && pct.isNotEmpty
          ? Decimal.tryParse(pct)
          : null,
      podeCobrar: podeCobrar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: nomeController,
          enabled: habilitado,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: Validatorless.regex(_notBlank, 'Informe o nome'),
          forceErrorText: erroDoCampo('nome'),
          onChanged: (_) => limparErroDoCampo('nome'),
          decoration: const InputDecoration(
            labelText: 'Nome',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: BrandSpacing.space4),
        TextFormField(
          controller: funcaoController,
          enabled: habilitado,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          forceErrorText: erroDoCampo('funcao'),
          onChanged: (_) => limparErroDoCampo('funcao'),
          decoration: const InputDecoration(
            labelText: 'Função (opcional)',
            hintText: 'Ex.: Barbeiro',
            prefixIcon: Icon(Icons.work_outline_rounded),
          ),
        ),

        const SizedBox(height: BrandSpacing.space5),
        Text('Vínculo', style: textos.titleSmall),
        const SizedBox(height: BrandSpacing.space1),
        Text(
          tipo == VinculoColaborador.parceiro
              ? 'Agenda e faturamento próprios. Vê os próprios números e '
                    'recebe a comissão combinada.'
              : 'Executa os atendimentos. Não vê valores; o dinheiro é do '
                    'negócio.',
          style: textos.bodySmall,
        ),
        const SizedBox(height: BrandSpacing.space2),
        SegmentedButton<VinculoColaborador>(
          segments: [
            for (final v in VinculoColaborador.values)
              ButtonSegment(value: v, label: Text(v.nome)),
          ],
          selected: {tipo},
          onSelectionChanged: habilitado ? (s) => onTipo(s.first) : null,
        ),

        if (tipo == VinculoColaborador.parceiro) ...[
          const SizedBox(height: BrandSpacing.space4),
          TextFormField(
            controller: comissaoController,
            enabled: habilitado,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final pct = Decimal.tryParse(v.trim().replaceAll(',', '.'));
              if (pct == null ||
                  pct < Decimal.zero ||
                  pct > Decimal.fromInt(100)) {
                return 'De 0 a 100';
              }
              return null;
            },
            forceErrorText: erroDoCampo('comissao_percentual'),
            onChanged: (_) => limparErroDoCampo('comissao_percentual'),
            decoration: const InputDecoration(
              labelText: 'Comissão (opcional)',
              helperText:
                  'A parte do parceiro em cada pagamento. Vale daqui para '
                  'frente: o que já foi cobrado não muda.',
              helperMaxLines: 2,
              suffixText: '%',
              prefixIcon: Icon(Icons.percent_rounded),
            ),
          ),
        ] else if (temAcesso)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pode registrar cobranças'),
            subtitle: const Text('Desligado, só o dono e os parceiros cobram.'),
            value: podeCobrar,
            onChanged: habilitado ? onPodeCobrar : null,
          ),
      ],
    );
  }
}
