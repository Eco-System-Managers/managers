import 'package:flutter/material.dart';

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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _veiculos ? Icons.directions_car_outlined : Icons.pets,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _veiculos ? 'Veículos' : 'Pets',
                    style: textos.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _novo(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            if (objetos.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _veiculos
                      ? 'Nenhum veículo cadastrado.'
                      : 'Nenhum pet cadastrado.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            for (final objeto in objetos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(objeto.titulo),
                subtitle: objeto.detalhe.isEmpty ? null : Text(objeto.detalhe),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () => _editar(context, objeto),
              ),
          ],
        ),
      ),
    );
  }
}
