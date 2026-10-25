import 'dart:async';

import 'package:flutter/material.dart';
import 'package:managers/core/widgets/avatar_iniciais.dart';
import 'package:managers/core/widgets/mascara_formatter.dart';
import 'package:managers/features/clientes/domain/entities/cliente.dart';

// a folha para escolher o cliente do agendamento: busca na API enquanto a
// pessoa digita e devolve o escolhido
class ClientePickerSheet extends StatefulWidget {
  const ClientePickerSheet({super.key, required this.buscar});

  final Future<List<Cliente>> Function(String busca) buscar;

  static Future<Cliente?> abrir(
    BuildContext context, {
    required Future<List<Cliente>> Function(String busca) buscar,
  }) {
    return showModalBottomSheet<Cliente>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ClientePickerSheet(buscar: buscar),
    );
  }

  @override
  State<ClientePickerSheet> createState() => _ClientePickerSheetState();
}

class _ClientePickerSheetState extends State<ClientePickerSheet> {
  final _controller = TextEditingController();
  final _telefoneMascara = MascaraFormatter.dinamica(MascaraFormatter.telefone);

  List<Cliente> _clientes = const [];
  bool _carregando = true;
  Timer? _debounce;

  // cada busca tem um número: a resposta de uma busca antiga é descartada
  int _busca = 0;

  @override
  void initState() {
    super.initState();
    _buscar('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _aoDigitar(String texto) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _buscar(texto));
  }

  Future<void> _buscar(String texto) async {
    final busca = ++_busca;
    setState(() => _carregando = true);
    final clientes = await widget.buscar(texto.trim());
    if (!mounted || busca != _busca) return;
    setState(() {
      _clientes = clientes;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final altura = MediaQuery.sizeOf(context).height * 0.8;

    return SizedBox(
      height: altura,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Escolher cliente',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _aoDigitar,
              decoration: const InputDecoration(
                hintText: 'Nome, telefone, e-mail ou CPF',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _clientes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _controller.text.isEmpty
                            ? 'Nenhum cliente cadastrado. Cadastre na aba '
                                  'Clientes.'
                            : 'Nenhum cliente encontrado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _clientes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final cliente = _clientes[index];
                      return ListTile(
                        leading: AvatarIniciais(
                          nome: cliente.nome,
                          fotoUrl: cliente.fotoUrl,
                        ),
                        title: Text(cliente.nome),
                        subtitle: Text(
                          _telefoneMascara.aplicar(cliente.telefone),
                        ),
                        onTap: () => Navigator.of(context).pop(cliente),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
