import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/widgets/avatar_iniciais.dart';
import 'package:managers/core/widgets/carregando.dart';
import 'package:managers/core/widgets/confirmar_dialog.dart';
import 'package:managers/core/widgets/estado_erro.dart';
import 'package:managers/core/widgets/mascara_formatter.dart';
import 'package:managers/features/agenda/presentation/widgets/historico_cliente_card.dart';
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:managers/features/financeiro/presentation/widgets/saldo_cliente_card.dart';
import 'package:managers/features/kanban/presentation/widgets/historico_kanban_card.dart';

import '../../clientes_provider.dart';
import '../../domain/entities/cliente.dart';
import '../providers/cliente_provider.dart';
import '../widgets/objetos_cliente_section.dart';

// a ficha do cliente: os dados, de onde veio o cadastro, o crédito na
// comanda (do financeiro), o histórico de atendimentos (da agenda), editar
// e remover
class ClientePage extends ConsumerStatefulWidget {
  const ClientePage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<ClientePage> createState() => _ClientePageState();
}

class _ClientePageState extends ConsumerState<ClientePage> {
  ClienteProvider get _provider => ref.read(clienteProvider(widget.id));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _provider.carregar();
    });
  }

  // a edição pode ter mudado a ficha: ela vem da API de novo
  Future<void> _editar() async {
    await context.push('/clientes/${widget.id}/editar');
    if (mounted) _provider.carregar();
  }

  Future<void> _remover(Cliente cliente) async {
    final ok = await confirmar(
      context,
      titulo: 'Remover cliente',
      mensagem: cliente.veioDoApp
          ? 'O cadastro de ${cliente.nome} deixa de aparecer para você e o '
                'vínculo com o app é desfeito. O histórico fica guardado.'
          : 'O cadastro de ${cliente.nome} é apagado. Clientes com '
                'atendimento registrado não podem ser removidos.',
      textoConfirmar: 'Remover',
      destrutivo: true,
    );
    if (!ok || !mounted) return;
    await _provider.remover();
  }

  @override
  Widget build(BuildContext context) {
    // watch: mantém o provider vivo enquanto a tela estiver aberta
    final provider = ref.watch(clienteProvider(widget.id));

    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        if (provider.removido) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop();
          });
        }

        final cliente = provider.cliente;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Cliente'),
            actions: cliente == null
                ? null
                : [
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: provider.isLoading ? null : _editar,
                    ),
                    IconButton(
                      tooltip: 'Remover',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: provider.isLoading
                          ? null
                          : () => _remover(cliente),
                    ),
                  ],
          ),
          body: _corpo(context, provider, cliente),
        );
      },
    );
  }

  Widget _corpo(
    BuildContext context,
    ClienteProvider provider,
    Cliente? cliente,
  ) {
    if (cliente == null) {
      final erro = provider.erroAoCarregar;
      if (erro != null) {
        return EstadoErro(
          mensagem: erro.message,
          onTentarDeNovo: provider.carregar,
        );
      }
      return const Carregando();
    }

    final colors = Theme.of(context).colorScheme;
    // o modo do negócio não muda com a ficha aberta: ler basta
    final negocio = ref.read(negocioAtualProvider);
    final tipoObjeto = negocio.config?.tipoObjeto;
    final telefone = MascaraFormatter.dinamica(MascaraFormatter.telefone)
        .aplicar(cliente.telefone);
    final cpf = MascaraFormatter(MascaraFormatter.cpf).aplicar(cliente.cpf);
    final endereco = [
      if (cliente.endereco.isNotEmpty)
        [
          cliente.endereco,
          if (cliente.numeroEndereco.isNotEmpty) cliente.numeroEndereco,
        ].join(', '),
      if (cliente.cep.isNotEmpty)
        'CEP ${MascaraFormatter(MascaraFormatter.cep).aplicar(cliente.cep)}',
    ].join(' · ');

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              AvatarIniciais(
                nome: cliente.nome,
                fotoUrl: cliente.fotoUrl,
                raio: 40,
              ),
              const SizedBox(height: 12),
              Text(
                cliente.nome,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (cliente.veioDoApp) ...[
                const SizedBox(height: 8),
                Chip(
                  avatar: const Icon(Icons.phone_android, size: 18),
                  label: const Text('Cadastro feito pelo app'),
                  backgroundColor: colors.secondaryContainer,
                ),
              ],
            ],
          ),
        ),
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.error),
            ),
          ),
        SaldoClienteCard(clienteId: cliente.id),
        const SizedBox(height: 8),
        // só os negócios por esteira recebem um objeto do cliente
        if (tipoObjeto != null) ...[
          ObjetosClienteSection(
            cliente: cliente,
            tipo: tipoObjeto,
            onMudou: provider.carregar,
          ),
          const SizedBox(height: 8),
        ],
        if (negocio.isKanban)
          HistoricoKanbanCard(clienteId: cliente.id)
        else
          HistoricoClienteCard(clienteId: cliente.id),
        const SizedBox(height: 8),
        const Divider(),
        _Dado(icone: Icons.phone_outlined, rotulo: 'Telefone', valor: telefone),
        _Dado(
          icone: Icons.email_outlined,
          rotulo: 'E-mail',
          valor: cliente.email,
        ),
        _Dado(icone: Icons.badge_outlined, rotulo: 'CPF', valor: cpf),
        _Dado(
          icone: Icons.cake_outlined,
          rotulo: 'Nascimento',
          valor: cliente.dataNascimento == null
              ? ''
              : formatarData(cliente.dataNascimento!),
        ),
        _Dado(icone: Icons.place_outlined, rotulo: 'Endereço', valor: endereco),
        _Dado(
          icone: Icons.notes_outlined,
          rotulo: 'Observação',
          valor: cliente.observacao,
        ),
        _Dado(
          icone: Icons.warning_amber_outlined,
          rotulo: 'Alergias',
          valor: cliente.alergia,
        ),
        _Dado(
          icone: Icons.event_available_outlined,
          rotulo: 'Cliente desde',
          valor: cliente.criadoEm == null
              ? ''
              : formatarData(cliente.criadoEm!),
        ),
      ],
    );
  }
}

// uma linha da ficha; o que está vazio aparece como "Não informado"
class _Dado extends StatelessWidget {
  const _Dado({required this.icone, required this.rotulo, required this.valor});

  final IconData icone;
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final vazio = valor.isEmpty;

    return ListTile(
      leading: Icon(icone),
      title: Text(rotulo, style: TextStyle(color: colors.onSurfaceVariant)),
      subtitle: Text(
        vazio ? 'Não informado' : valor,
        style: TextStyle(
          color: vazio ? colors.outline : colors.onSurface,
          fontStyle: vazio ? FontStyle.italic : null,
        ),
      ),
    );
  }
}
