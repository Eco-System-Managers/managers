import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/widgets/avatar_iniciais.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/features/clientes/presentation/widgets/cliente_picker_sheet.dart';
import 'package:managers/features/empresa/empresa_provider.dart';

import '../../contratos_provider.dart';
import '../providers/gerar_contrato_provider.dart';

// gera um contrato: o modelo e o cliente. fecha devolvendo o id do contrato
// criado, para quem chamou abrir a ficha dele
class GerarContratoPage extends ConsumerStatefulWidget {
  const GerarContratoPage({super.key, this.clienteId});

  // vindo da ficha do cliente, ele já chega escolhido
  final int? clienteId;

  @override
  ConsumerState<GerarContratoPage> createState() => _GerarContratoPageState();
}

class _GerarContratoPageState extends ConsumerState<GerarContratoPage> {
  GerarContratoProvider get _provider =>
      ref.read(gerarContratoProvider(widget.clienteId));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  Future<void> _escolherCliente() async {
    final cliente = await ClientePickerSheet.abrir(
      context,
      buscar: _provider.buscarClientes,
    );
    if (cliente == null || !mounted) return;
    _provider.selecionarCliente(cliente);
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(gerarContratoProvider(widget.clienteId));

    return Scaffold(
      appBar: AppBar(title: const Text('Gerar contrato')),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          final gerado = provider.gerado;
          if (gerado != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.pop(gerado.id);
            });
          }

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

          return _formulario(context, provider);
        },
      ),
    );
  }

  Widget _formulario(BuildContext context, GerarContratoProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final cliente = provider.cliente;
    final erroModelo = provider.erroDoCampo('modelo');
    final erroCliente = provider.erroDoCampo('cliente');

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (provider.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              provider.errorMessage!,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Text('Modelo', style: textos.titleSmall),
        const SizedBox(height: 4),
        if (provider.modelos.isEmpty) ...[
          Text(
            'Nenhum modelo ativo. O modelo é o texto do contrato, com as '
            'variáveis que viram os dados do cliente.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          // o modelo é escrita do proprietário
          if (ref.read(negocioAtualProvider).ehProprietario)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final criou = await context.push<bool>(
                    '/mais/contratos/modelos/novo',
                  );
                  if (criou == true && mounted) _provider.carregar();
                },
                icon: const Icon(Icons.add),
                label: const Text('Criar modelo'),
              ),
            ),
        ] else
          for (final m in provider.modelos)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                provider.modelo?.id == m.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: provider.modelo?.id == m.id ? colors.primary : null,
              ),
              title: Text(m.titulo),
              subtitle: Text(
                m.corpo.replaceAll('\n', ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => provider.selecionarModelo(m),
            ),
        if (erroModelo != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              erroModelo,
              style: textos.bodySmall?.copyWith(color: colors.error),
            ),
          ),

        const SizedBox(height: 24),
        Text('Cliente', style: textos.titleSmall),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: cliente == null
              ? const CircleAvatar(child: Icon(Icons.person_outline))
              : AvatarIniciais(nome: cliente.nome, fotoUrl: cliente.fotoUrl),
          title: Text(cliente?.nome ?? 'Escolher cliente'),
          subtitle: cliente == null
              ? null
              : Text(
                  cliente.email.isEmpty ? 'Sem e-mail' : cliente.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: const Icon(Icons.chevron_right),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: erroCliente == null ? colors.outline : colors.error,
            ),
          ),
          onTap: _escolherCliente,
        ),
        if (erroCliente != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              erroCliente,
              style: textos.bodySmall?.copyWith(color: colors.error),
            ),
          ),

        const SizedBox(height: 8),
        Text(
          'As variáveis do modelo viram os dados deste cliente e a data de '
          'hoje. O texto fica congelado no contrato.',
          style: textos.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),

        const SizedBox(height: 24),
        FilledButton(
          onPressed: provider.isLoading ? null : provider.gerar,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Gerar'),
        ),
      ],
    );
  }
}
