import 'package:flutter/material.dart';
import 'package:managers/core/theme/brand.dart';

import '../../domain/entities/cliente.dart';
import '../../domain/entities/objeto_cliente.dart';
import 'pet_form_sheet.dart';
import 'veiculo_form_sheet.dart';

// os veículos ou os pets do cliente, na ficha: só nos negócios por esteira,
// que recebem um objeto. o tipo vem da config do negócio
class ObjetosClienteSection extends StatelessWidget {
  const ObjetosClienteSection({
    super.key,
    required this.cliente,
    required this.tipo,
    required this.onMudou,
  });

  final Cliente cliente;
  final TipoObjeto tipo;

  // a ficha recarrega da API: os objetos vêm aninhados no cliente
  final Future<void> Function() onMudou;

  bool get _veiculos => tipo == TipoObjeto.veiculo;

  Future<void> _novo(BuildContext context) async {
    final mudou = _veiculos
        ? await VeiculoFormSheet.abrir(context, clienteId: cliente.id)
        : await PetFormSheet.abrir(context, clienteId: cliente.id);
    if (mudou) await onMudou();
  }

  Future<void> _editar(BuildContext context, ObjetoCliente objeto) async {
    final mudou = objeto.veiculo != null
        ? await VeiculoFormSheet.abrir(
            context,
            clienteId: cliente.id,
            veiculo: objeto.veiculo,
          )
        : await PetFormSheet.abrir(
            context,
            clienteId: cliente.id,
            pet: objeto.pet,
          );
    if (mudou) await onMudou();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final objetos = cliente.objetosDoTipo(tipo);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: BrandSpacing.space4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BrandSpacing.space4,
          BrandSpacing.space2,
          BrandSpacing.space2,
          BrandSpacing.space2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // o ícone do cartão é neutro: o azul fica para o "Adicionar"
            Row(
              children: [
                Icon(
                  _veiculos ? Icons.directions_car_rounded : Icons.pets_rounded,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: BrandSpacing.space2),
                Expanded(
                  child: Text(
                    _veiculos ? 'Veículos' : 'Pets',
                    style: textos.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _novo(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            if (objetos.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: BrandSpacing.space2),
                child: Text(
                  _veiculos
                      ? 'Nenhum veículo cadastrado.'
                      : 'Nenhum pet cadastrado.',
                  style: textos.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            for (final objeto in objetos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(objeto.titulo),
                subtitle: objeto.detalhe.isEmpty ? null : Text(objeto.detalhe),
                trailing: const Icon(Icons.mode_edit_outline_rounded, size: 20),
                onTap: () => _editar(context, objeto),
              ),
          ],
        ),
      ),
    );
  }
}
