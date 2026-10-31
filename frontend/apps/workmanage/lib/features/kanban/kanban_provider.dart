import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/network/dio_client.dart';
import 'package:managers/features/agenda/agenda_provider.dart'
    show
        excluirBloqueioUseCaseProvider,
        listarBloqueiosDoDiaUseCaseProvider,
        listarPendenciasUseCaseProvider;
import 'package:managers/features/clientes/clientes_provider.dart';
import 'package:managers/features/clientes/domain/entities/objeto_cliente.dart';
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:managers/features/financeiro/financeiro_provider.dart';
import 'package:managers/features/servicos/servicos_provider.dart';
import 'package:managers/features/usuarios/usuarios_provider.dart';

import 'data/datasources/kanban_remote_datasource.dart';
import 'data/repositories/kanban_repository_impl.dart';
import 'domain/repositories/kanban_repository.dart';
import 'domain/usecases/kanban_use_cases.dart';
import 'presentation/providers/atendimento_kanban_form_provider.dart';
import 'presentation/providers/atendimento_kanban_provider.dart';
import 'presentation/providers/etapas_provider.dart';
import 'presentation/providers/historico_kanban_provider.dart';
import 'presentation/providers/quadro_provider.dart';

// injeção de dependências da esteira: é o único lugar que conhece as
// implementações. o formulário usa clientes e serviços; a ficha usa o saldo
// do financeiro e o quadro do dia (quem vem depois de um card atrasado); o
// quadro conta as pendências de cobrança e lê os horários fechados do
// negócio com os use cases da agenda (a API junta os dois modos)
final kanbanRemoteDataSourceProvider = Provider<KanbanRemoteDataSource>(
  (ref) => KanbanRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final kanbanRepositoryProvider = Provider<KanbanRepository>(
  (ref) => KanbanRepositoryImpl(ref.watch(kanbanRemoteDataSourceProvider)),
);

final listarEtapasUseCaseProvider = Provider(
  (ref) => ListarEtapasUseCase(ref.watch(kanbanRepositoryProvider)),
);

final salvarEtapaUseCaseProvider = Provider(
  (ref) => SalvarEtapaUseCase(ref.watch(kanbanRepositoryProvider)),
);

final removerEtapaUseCaseProvider = Provider(
  (ref) => RemoverEtapaUseCase(ref.watch(kanbanRepositoryProvider)),
);

final reordenarEtapasUseCaseProvider = Provider(
  (ref) => ReordenarEtapasUseCase(ref.watch(kanbanRepositoryProvider)),
);

final marcarEtapaProntoUseCaseProvider = Provider(
  (ref) => MarcarEtapaProntoUseCase(ref.watch(kanbanRepositoryProvider)),
);

final listarAtendimentosDoDiaUseCaseProvider = Provider(
  (ref) => ListarAtendimentosDoDiaUseCase(ref.watch(kanbanRepositoryProvider)),
);

final listarAtendimentosKanbanDoClienteUseCaseProvider = Provider(
  (ref) => ListarAtendimentosKanbanDoClienteUseCase(
    ref.watch(kanbanRepositoryProvider),
  ),
);

final obterAtendimentoKanbanUseCaseProvider = Provider(
  (ref) => ObterAtendimentoKanbanUseCase(ref.watch(kanbanRepositoryProvider)),
);

final criarAtendimentoKanbanUseCaseProvider = Provider(
  (ref) => CriarAtendimentoKanbanUseCase(ref.watch(kanbanRepositoryProvider)),
);

final moverAtendimentoUseCaseProvider = Provider(
  (ref) => MoverAtendimentoUseCase(ref.watch(kanbanRepositoryProvider)),
);

final remarcarAtendimentoKanbanUseCaseProvider = Provider(
  (ref) =>
      RemarcarAtendimentoKanbanUseCase(ref.watch(kanbanRepositoryProvider)),
);

final ajustarTempoAtendimentoUseCaseProvider = Provider(
  (ref) => AjustarTempoAtendimentoUseCase(ref.watch(kanbanRepositoryProvider)),
);

final cobrarAtendimentoKanbanUseCaseProvider = Provider(
  (ref) => CobrarAtendimentoKanbanUseCase(ref.watch(kanbanRepositoryProvider)),
);

final desfazerCobrancaUseCaseProvider = Provider(
  (ref) => DesfazerCobrancaUseCase(ref.watch(kanbanRepositoryProvider)),
);

final alterarFaltaUseCaseProvider = Provider(
  (ref) => AlterarFaltaUseCase(ref.watch(kanbanRepositoryProvider)),
);

final removerAtendimentoKanbanUseCaseProvider = Provider(
  (ref) => RemoverAtendimentoKanbanUseCase(ref.watch(kanbanRepositoryProvider)),
);

final listarSlotsKanbanUseCaseProvider = Provider(
  (ref) => ListarSlotsKanbanUseCase(ref.watch(kanbanRepositoryProvider)),
);

final obterCapacidadeDoDiaUseCaseProvider = Provider(
  (ref) => ObterCapacidadeDoDiaUseCase(ref.watch(kanbanRepositoryProvider)),
);

final ajustarCapacidadeDoDiaUseCaseProvider = Provider(
  (ref) => AjustarCapacidadeDoDiaUseCase(ref.watch(kanbanRepositoryProvider)),
);

final desfazerAjusteDoDiaUseCaseProvider = Provider(
  (ref) => DesfazerAjusteDoDiaUseCase(ref.watch(kanbanRepositoryProvider)),
);

// estado das telas. o quadro não é autoDispose: trocar de aba e voltar
// mantém o dia escolhido; ele recarrega ao voltar de qualquer tela
final quadroProvider = Provider<QuadroProvider>((ref) {
  final provider = QuadroProvider(
    listarEtapas: ref.watch(listarEtapasUseCaseProvider),
    listarDoDia: ref.watch(listarAtendimentosDoDiaUseCaseProvider),
    mover: ref.watch(moverAtendimentoUseCaseProvider),
    listarPendencias: ref.watch(listarPendenciasUseCaseProvider),
    listarColaboradores: ref.watch(listarColaboradoresUseCaseProvider),
    obterCapacidade: ref.watch(obterCapacidadeDoDiaUseCaseProvider),
    ajustarCapacidade: ref.watch(ajustarCapacidadeDoDiaUseCaseProvider),
    desfazerAjuste: ref.watch(desfazerAjusteDoDiaUseCaseProvider),
    listarBloqueios: ref.watch(listarBloqueiosDoDiaUseCaseProvider),
    excluirBloqueio: ref.watch(excluirBloqueioUseCaseProvider),
    ehProprietario: () => ref.read(negocioAtualProvider).ehProprietario,
  );
  ref.onDispose(provider.dispose);
  return provider;
});

// family: o dia em que o formulário abre (o dia aberto no quadro)
final atendimentoKanbanFormProvider = Provider.autoDispose
    .family<AtendimentoKanbanFormProvider, DateTime?>((ref, dataInicial) {
      final provider = AtendimentoKanbanFormProvider(
        listarEtapas: ref.watch(listarEtapasUseCaseProvider),
        listarServicos: ref.watch(listarServicosUseCaseProvider),
        listarClientes: ref.watch(listarClientesUseCaseProvider),
        obterCliente: ref.watch(obterClienteUseCaseProvider),
        listarSlots: ref.watch(listarSlotsKanbanUseCaseProvider),
        listarColaboradores: ref.watch(listarColaboradoresUseCaseProvider),
        criar: ref.watch(criarAtendimentoKanbanUseCaseProvider),
        tipoObjeto:
            ref.watch(negocioAtualProvider).config?.tipoObjeto ??
            TipoObjeto.veiculo,
        dataInicial: dataInicial,
      );
      ref.onDispose(provider.dispose);
      return provider;
    });

// family: um provider por card aberto
final atendimentoKanbanProvider = Provider.autoDispose
    .family<AtendimentoKanbanProvider, int>((ref, id) {
      final provider = AtendimentoKanbanProvider(
        id: id,
        obter: ref.watch(obterAtendimentoKanbanUseCaseProvider),
        listarEtapas: ref.watch(listarEtapasUseCaseProvider),
        listarDoDia: ref.watch(listarAtendimentosDoDiaUseCaseProvider),
        mover: ref.watch(moverAtendimentoUseCaseProvider),
        remarcar: ref.watch(remarcarAtendimentoKanbanUseCaseProvider),
        ajustarTempo: ref.watch(ajustarTempoAtendimentoUseCaseProvider),
        listarSlots: ref.watch(listarSlotsKanbanUseCaseProvider),
        cobrar: ref.watch(cobrarAtendimentoKanbanUseCaseProvider),
        desfazerCobranca: ref.watch(desfazerCobrancaUseCaseProvider),
        alterarFalta: ref.watch(alterarFaltaUseCaseProvider),
        remover: ref.watch(removerAtendimentoKanbanUseCaseProvider),
        obterSaldo: ref.watch(obterSaldoClienteUseCaseProvider),
        listarServicos: ref.watch(listarServicosUseCaseProvider),
      );
      ref.onDispose(provider.dispose);
      return provider;
    });

final etapasProvider = Provider.autoDispose<EtapasProvider>((ref) {
  final provider = EtapasProvider(
    listar: ref.watch(listarEtapasUseCaseProvider),
    salvar: ref.watch(salvarEtapaUseCaseProvider),
    remover: ref.watch(removerEtapaUseCaseProvider),
    reordenar: ref.watch(reordenarEtapasUseCaseProvider),
    marcarPronto: ref.watch(marcarEtapaProntoUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

// family: um provider por ficha de cliente aberta
final historicoKanbanProvider = Provider.autoDispose
    .family<HistoricoKanbanProvider, int>((ref, clienteId) {
      final provider = HistoricoKanbanProvider(
        clienteId: clienteId,
        listar: ref.watch(listarAtendimentosKanbanDoClienteUseCaseProvider),
      );
      ref.onDispose(provider.dispose);
      return provider;
    });
