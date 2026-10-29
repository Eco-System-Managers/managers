import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/widgets/avatar_iniciais.dart';
import 'package:managers/core/widgets/folha.dart';
import 'package:managers/core/widgets/mascara_formatter.dart';

import '../../domain/entities/cliente.dart';

// a folha para escolher o cliente de um agendamento ou atendimento: busca na
// API enquanto a pessoa digita e devolve o escolhido. quem não existe é
// cadastrado dali mesmo, com o que foi digitado já no campo, e volta
// escolhido
class ClientePickerSheet extends StatefulWidget {
  const ClientePickerSheet({super.key, required this.buscar});

  final Future<List<Cliente>> Function(String busca) buscar;

  static Future<Cliente?> abrir(
    BuildContext context, {
    required Future<List<Cliente>> Function(String busca) buscar,
  }) {
    return abrirFolha<Cliente>(
      context,
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

  // o que foi digitado vai para a ficha nova: só dígitos é telefone, o
  // resto é nome. a ficha devolve o cliente criado, e ele sai escolhido
  Future<void> _cadastrar() async {
    final texto = _controller.text.trim();
    final telefone =
        RegExp(r'^[\d\s()+-]+$').hasMatch(texto) && texto.isNotEmpty;
    final campo = telefone ? 'telefone' : 'nome';
    final uri = Uri(
      path: '/clientes/novo',
      queryParameters: texto.isEmpty ? null : {campo: texto},
    );
    final criado = await context.push<Cliente>(uri.toString());
    if (criado != null && mounted) Navigator.of(context).pop(criado);
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
    final textos = Theme.of(context).textTheme;
    final altura = MediaQuery.sizeOf(context).height * 0.8;

    return SizedBox(
      height: altura,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BrandSpacing.space4,
              BrandSpacing.space4,
              BrandSpacing.space4,
              BrandSpacing.space2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Escolher cliente', style: textos.titleLarge),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BrandSpacing.space4,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _aoDigitar,
              decoration: const InputDecoration(
                hintText: 'Nome, telefone, e-mail ou CPF',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: BrandSpacing.space2),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _clientes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(BrandSpacing.space5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _controller.text.trim().isEmpty
                                ? 'Nenhum cliente cadastrado ainda.'
                                : 'Nenhum cliente encontrado.',
                            textAlign: TextAlign.center,
                            style: textos.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: BrandSpacing.space4),
                          FilledButton.icon(
                            onPressed: _cadastrar,
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: Text(
                              _controller.text.trim().isEmpty
                                  ? 'Cadastrar cliente'
                                  : 'Cadastrar "${_controller.text.trim()}"',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
          // sempre à mão, mesmo com resultados: o cliente pode ser outro
          if (!_carregando && _clientes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BrandSpacing.space4,
                BrandSpacing.space2,
                BrandSpacing.space4,
                BrandSpacing.space2,
              ),
              child: OutlinedButton.icon(
                onPressed: _cadastrar,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Novo cliente'),
              ),
            ),
        ],
      ),
    );
  }
}
