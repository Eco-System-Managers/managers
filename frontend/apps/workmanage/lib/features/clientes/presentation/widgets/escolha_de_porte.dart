import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';

import '../../domain/entities/objeto_cliente.dart';

// como cada porte aparece na tela. o veículo vai por ícone, que ninguém
// confunde; o pet vai pelo peso, sem ícone. o switch sem default faz o
// analyze reclamar se um porte novo entrar no enum sem ícone aqui
extension PorteVisual on Porte {
  IconData? get icone => switch (this) {
    Porte.moto => Icons.two_wheeler_rounded,
    Porte.carro => Icons.directions_car_rounded,
    // não há ícone de caminhonete; o rótulo, que vai junto, diz qual é
    Porte.suv => Icons.directions_car_filled_rounded,
    Porte.van => Icons.airport_shuttle_rounded,
    Porte.caminhao => Icons.local_shipping_rounded,
    Porte.pequeno || Porte.medio || Porte.grande || Porte.gigante => null,
  };

  // "Moto" / "Pequeno · até 10 kg"
  String get rotulo => faixa.isEmpty ? nome : '$nome · $faixa';
}

// a escolha do porte de um veículo ou pet, em chips. é campo de formulário:
// obrigatório, com o erro (o da validação ou o da API) embaixo
class EscolhaDePorte extends FormField<Porte> {
  EscolhaDePorte({
    super.key,
    required TipoObjeto tipo,
    required Porte? valor,
    required ValueChanged<Porte> onChanged,
    super.forceErrorText,
  }) : super(
         initialValue: valor,
         validator: (porte) => porte == null ? 'Escolha o porte' : null,
         builder: (campo) {
           final context = campo.context;
           final colors = Theme.of(context).colorScheme;
           final textos = Theme.of(context).textTheme;

           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(
                 tipo == TipoObjeto.veiculo
                     ? 'Porte do veículo'
                     : 'Porte, pelo peso',
                 style: textos.titleSmall,
               ),
               const SizedBox(height: BrandSpacing.space2),
               Wrap(
                 spacing: BrandSpacing.space2,
                 runSpacing: BrandSpacing.space2,
                 children: [
                   for (final porte in Porte.doTipo(tipo))
                     ChoiceChip(
                       // o selecionado já vai em blueSoft: o ícone fica
                       showCheckmark: false,
                       avatar: porte.icone == null ? null : Icon(porte.icone),
                       label: Text(porte.rotulo),
                       selected: campo.value == porte,
                       onSelected: (_) {
                         campo.didChange(porte);
                         onChanged(porte);
                       },
                     ),
                 ],
               ),
               if (campo.hasError) ...[
                 const SizedBox(height: BrandSpacing.space2),
                 Text(
                   campo.errorText!,
                   style: textos.bodySmall?.copyWith(color: colors.error),
                 ),
               ],
             ],
           );
         },
       );
}
