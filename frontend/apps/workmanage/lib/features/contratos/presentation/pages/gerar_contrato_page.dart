import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/widgets/avatar_iniciais.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/folha.dart';
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
    final cores = BrandColors.of(context);
    final textos = Theme.of(context).textTheme;
    final cliente = provider.cliente;
    final erroModelo = provider.erroDoCampo('modelo');
    final erroCliente = provider.erroDoCampo('cliente');

    return ListView(
      padding: paddingDaPagina(context),
      children: [
        if (provider.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(BrandSpacing.space3),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BrandRadius.mdAll,
            ),
            child: Text(
              provider.errorMessage!,
              style: textos.bodyMedium?.copyWith(
                color: colors.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(height: BrandSpacing.space4),
        ],

        Text('Modelo', style: textos.titleSmall),
        const SizedBox(height: BrandSpacing.space1),
        if (provider.modelos.isEmpty) ...[
          Text(
            'Nenhum modelo ativo. O modelo é o texto do contrato, com as '
            'variáveis que viram os dados do cliente.',
            style: textos.bodyMedium?.copyWith(color: cores.inkMuted),
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
                icon: const Icon(Icons.add_rounded),
                label: const Text('Criar modelo'),
              ),
            ),
        ] else
          for (final m in provider.modelos)
            ListTile(
              contentPadding: EdgeInsets.zero,
              // o escolhido é o único azul da lista: estado ativo
              leading: Icon(
                provider.modelo?.id == m.id
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
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
            padding: const EdgeInsets.only(top: BrandSpacing.space1),
            child: Text(
              erroModelo,
              style: textos.bodySmall?.copyWith(color: colors.error),
            ),
          ),

        const SizedBox(height: BrandSpacing.space5),
        Text('Cliente', style: textos.titleSmall),
        const SizedBox(height: BrandSpacing.space1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: cliente == null
              ? const CircleAvatar(child: Icon(Icons.person_outline_rounded))
              : AvatarIniciais(nome: cliente.nome, fotoUrl: cliente.fotoUrl),
          title: Text(cliente?.nome ?? 'Escolher cliente'),
          subtitle: cliente == null
              ? null
              : Text(
                  cliente.email.isEmpty ? 'Sem e-mail' : cliente.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: const Icon(Icons.chevron_right_rounded),
          // a linha funciona como um campo: raio sm e a borda, que vira
          // danger quando falta escolher
          shape: RoundedRectangleBorder(
            borderRadius: BrandRadius.smAll,
            side: BorderSide(
              color: erroCliente == null ? cores.border : cores.danger,
            ),
          ),
          onTap: _escolherCliente,
        ),
        if (erroCliente != null)
          Padding(
            padding: const EdgeInsets.only(top: BrandSpacing.space1),
            child: Text(
              erroCliente,
              style: textos.bodySmall?.copyWith(color: colors.error),
            ),
          ),

        const SizedBox(height: BrandSpacing.space2),
        Text(
          'As variáveis do modelo viram os dados deste cliente e a data de '
          'hoje. O texto fica congelado no contrato.',
          style: textos.bodySmall,
        ),

        const SizedBox(height: BrandSpacing.space5),
        FilledButton(
          onPressed: provider.isLoading ? null : provider.gerar,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Gerar'),
        ),
      ],
    );
  }
}
