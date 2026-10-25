import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/core/network/dio_client.dart';
import 'package:managers/features/clientes/clientes_provider.dart';
import 'package:managers/features/empresa/empresa_provider.dart';
import 'package:managers/features/financeiro/financeiro_provider.dart';
import 'package:managers/features/servicos/servicos_provider.dart';
import 'package:managers/features/usuarios/usuarios_provider.dart';

import 'data/datasources/agenda_remote_datasource.dart';
import 'data/repositories/agenda_repository_impl.dart';
import 'domain/repositories/agenda_repository.dart';
import 'domain/usecases/agenda_use_cases.dart';
import 'presentation/providers/agenda_dia_provider.dart';
import 'presentation/providers/agendamento_form_provider.dart';
import 'presentation/providers/agendamento_provider.dart';
import 'presentation/providers/historico_cliente_provider.dart';
import 'presentation/providers/pendencias_provider.dart';

// injeção de dependências da agenda: é o único lugar que conhece as
// implementações. o formulário usa os use cases de clientes, serviços e
// equipe; a ficha usa o saldo do financeiro
final agendaRemoteDataSourceProvider = Provider<AgendaRemoteDataSource>(
  (ref) => AgendaRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final agendaRepositoryProvider = Provider<AgendaRepository>(
  (ref) => AgendaRepositoryImpl(ref.watch(agendaRemoteDataSourceProvider)),
);

final listarAgendamentosDoDiaUseCaseProvider = Provider(
  (ref) => ListarAgendamentosDoDiaUseCase(ref.watch(agendaRepositoryProvider)),
);

final listarAgendamentosDoClienteUseCaseProvider = Provider(
  (ref) =>
      ListarAgendamentosDoClienteUseCase(ref.watch(agendaRepositoryProvider)),
);

final obterAgendamentoUseCaseProvider = Provider(
  (ref) => ObterAgendamentoUseCase(ref.watch(agendaRepositoryProvider)),
);

final criarAgendamentoUseCaseProvider = Provider(
  (ref) => CriarAgendamentoUseCase(ref.watch(agendaRepositoryProvider)),
);

final alterarStatusAgendamentoUseCaseProvider = Provider(
  (ref) => AlterarStatusAgendamentoUseCase(ref.watch(agendaRepositoryProvider)),
);

final remarcarAgendamentoUseCaseProvider = Provider(
  (ref) => RemarcarAgendamentoUseCase(ref.watch(agendaRepositoryProvider)),
);

final cobrarAgendamentoUseCaseProvider = Provider(
  (ref) => CobrarAgendamentoUseCase(ref.watch(agendaRepositoryProvider)),
);

final listarSlotsUseCaseProvider = Provider(
  (ref) => ListarSlotsUseCase(ref.watch(agendaRepositoryProvider)),
);

final listarDiasComRegistroUseCaseProvider = Provider(
  (ref) => ListarDiasComRegistroUseCase(ref.watch(agendaRepositoryProvider)),
);

final listarPendenciasUseCaseProvider = Provider(
  (ref) => ListarPendenciasUseCase(ref.watch(agendaRepositoryProvider)),
);

// estado das telas. a agenda do dia não é autoDispose: trocar de aba e
// voltar mantém o dia escolhido; a lista recarrega ao voltar de qualquer tela
final agendaDiaProvider = Provider<AgendaDiaProvider>((ref) {
  final provider = AgendaDiaProvider(
    listarDoDia: ref.watch(listarAgendamentosDoDiaUseCaseProvider),
    listarDiasComRegistro: ref.watch(listarDiasComRegistroUseCaseProvider),
    listarColaboradores: ref.watch(listarColaboradoresUseCaseProvider),
    listarPendencias: ref.watch(listarPendenciasUseCaseProvider),
    buscarHorarios: ref.watch(buscarHorariosUseCaseProvider),
    listarServicos: ref.watch(listarServicosUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});

// family: com o que o formulário abre (dia, hora e profissional tocados na
// grade da agenda)
final agendamentoFormProvider = Provider.autoDispose
    .family<AgendamentoFormProvider, NovoAgendamentoArgs>((ref, args) {
      final provider = AgendamentoFormProvider(
        listarServicos: ref.watch(listarServicosUseCaseProvider),
        listarColaboradores: ref.watch(listarColaboradoresUseCaseProvider),
        listarClientes: ref.watch(listarClientesUseCaseProvider),
        listarSlots: ref.watch(listarSlotsUseCaseProvider),
        criar: ref.watch(criarAgendamentoUseCaseProvider),
        colaboradorInicialId:
            args.colaboradorId ?? ref.watch(negocioAtualProvider).perfil?.id,
        dataInicial: args.data,
        horaInicial: args.hora,
      );
      ref.onDispose(provider.dispose);
      return provider;
    });

// family: um provider por ficha aberta
final agendamentoProvider = Provider.autoDispose
    .family<AgendamentoProvider, int>((ref, id) {
      final provider = AgendamentoProvider(
        id: id,
        obter: ref.watch(obterAgendamentoUseCaseProvider),
        alterarStatus: ref.watch(alterarStatusAgendamentoUseCaseProvider),
        remarcar: ref.watch(remarcarAgendamentoUseCaseProvider),
        cobrar: ref.watch(cobrarAgendamentoUseCaseProvider),
        listarSlots: ref.watch(listarSlotsUseCaseProvider),
        obterSaldo: ref.watch(obterSaldoClienteUseCaseProvider),
      );
      ref.onDispose(provider.dispose);
      return provider;
    });

// family: um provider por ficha de cliente aberta
final historicoClienteProvider = Provider.autoDispose
    .family<HistoricoClienteProvider, int>((ref, clienteId) {
      final provider = HistoricoClienteProvider(
        clienteId: clienteId,
        listar: ref.watch(listarAgendamentosDoClienteUseCaseProvider),
      );
      ref.onDispose(provider.dispose);
      return provider;
    });

final pendenciasProvider = Provider.autoDispose<PendenciasProvider>((ref) {
  final provider = PendenciasProvider(
    listar: ref.watch(listarPendenciasUseCaseProvider),
  );
  ref.onDispose(provider.dispose);
  return provider;
});
