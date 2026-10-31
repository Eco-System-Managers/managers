import 'package:dartz/dartz.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/clientes/domain/entities/objeto_cliente.dart';
import 'package:managers/features/financeiro/domain/entities/pagamento.dart';
import 'package:managers/features/financeiro/domain/entities/saldo_cliente.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';
import 'package:managers/features/financeiro/domain/usecases/financeiro_use_cases.dart';
import 'package:managers/features/kanban/domain/entities/atendimento_kanban.dart';
import 'package:managers/features/kanban/domain/entities/etapa.dart';
import 'package:managers/features/kanban/domain/params/kanban_params.dart';
import 'package:managers/features/kanban/domain/usecases/kanban_use_cases.dart';
import 'package:managers/features/kanban/presentation/providers/atendimento_kanban_provider.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';
import 'package:managers/features/servicos/domain/params/listar_servicos_params.dart';
import 'package:managers/features/servicos/domain/usecases/listar_servicos_use_case.dart';
import 'package:mocktail/mocktail.dart';

class _MockObter extends Mock implements ObterAtendimentoKanbanUseCase {}

class _MockListarEtapas extends Mock implements ListarEtapasUseCase {}

class _MockListarDoDia extends Mock implements ListarAtendimentosDoDiaUseCase {}

class _MockMover extends Mock implements MoverAtendimentoUseCase {}

class _MockRemarcar extends Mock implements RemarcarAtendimentoKanbanUseCase {}

class _MockAjustarTempo extends Mock
    implements AjustarTempoAtendimentoUseCase {}

class _MockListarSlots extends Mock implements ListarSlotsKanbanUseCase {}

class _MockCobrar extends Mock implements CobrarAtendimentoKanbanUseCase {}

class _MockDesfazerCobranca extends Mock implements DesfazerCobrancaUseCase {}

class _MockAlterarFalta extends Mock implements AlterarFaltaUseCase {}

class _MockRemover extends Mock implements RemoverAtendimentoKanbanUseCase {}

class _MockObterSaldo extends Mock implements ObterSaldoClienteUseCase {}

class _MockListarServicos extends Mock implements ListarServicosUseCase {}

const _uno = Veiculo(
  id: 10,
  clienteId: 7,
  placa: 'ABC1D23',
  marca: 'Fiat',
  modelo: 'Uno',
  cor: 'Prata',
);

AtendimentoKanban _card({
  int etapaId = 1,
  bool pago = false,
  bool faltou = false,
  DateTime? data,
  Hora? hora,
  int minutosExtras = 0,
  DateTime? prontoEm,
  ObjetoCliente? objeto = const ObjetoCliente.veiculo(_uno),
}) => AtendimentoKanban(
  id: 3,
  etapaId: etapaId,
  etapaNome: 'Aguardando',
  objeto: objeto,
  clienteNome: 'Ana Silva',
  clienteTelefone: '19999990000',
  servicoId: 3,
  servicoNome: 'Lavagem',
  servicoPreco: Decimal.fromInt(60),
  servicoDuracao: 40,
  data: data,
  horarioEntrada: hora,
  pago: pago,
  faltou: faltou,
  minutosExtras: minutosExtras,
  prontoEm: prontoEm,
);

final _saldo = SaldoCliente(saldo: Decimal.fromInt(5), transacoes: const []);
final _quinta = DateTime(2026, 11, 5);
const _nove = (hora: 9, minuto: 0);

void main() {
  late _MockObter obter;
  late _MockListarEtapas listarEtapas;
  late _MockListarDoDia listarDoDia;
  late _MockMover mover;
  late _MockRemarcar remarcar;
  late _MockAjustarTempo ajustarTempo;
  late _MockListarSlots listarSlots;
  late _MockCobrar cobrar;
  late _MockDesfazerCobranca desfazerCobranca;
  late _MockAlterarFalta alterarFalta;
  late _MockRemover remover;
  late _MockObterSaldo obterSaldo;
  late _MockListarServicos listarServicos;

  setUpAll(() {
    registerFallbackValue(NoParams());
    registerFallbackValue(const MoverAtendimentoParams(id: 0, etapaId: 0));
    registerFallbackValue(CobrancaParams(id: 0, pagamentos: const []));
    registerFallbackValue(const AlterarFaltaParams(id: 0, faltou: true));
    registerFallbackValue(
      RemarcarAtendimentoKanbanParams(id: 0, data: _quinta),
    );
    registerFallbackValue(const AjustarTempoParams(id: 0, minutosExtras: 0));
    registerFallbackValue(SlotsKanbanParams(data: _quinta));
    registerFallbackValue(ListarDoDiaParams(data: _quinta));
    registerFallbackValue(const ListarServicosParams());
  });

  AtendimentoKanbanProvider montar({bool comCatalogo = false}) =>
      AtendimentoKanbanProvider(
        id: 3,
        obter: obter,
        listarEtapas: listarEtapas,
        listarDoDia: listarDoDia,
        mover: mover,
        remarcar: remarcar,
        ajustarTempo: ajustarTempo,
        listarSlots: listarSlots,
        cobrar: cobrar,
        desfazerCobranca: desfazerCobranca,
        alterarFalta: alterarFalta,
        remover: remover,
        obterSaldo: obterSaldo,
        listarServicos: comCatalogo ? listarServicos : null,
      );

  setUp(() {
    obter = _MockObter();
    listarEtapas = _MockListarEtapas();
    listarDoDia = _MockListarDoDia();
    when(() => listarDoDia(any())).thenAnswer((_) async => const Right([]));
    mover = _MockMover();
    remarcar = _MockRemarcar();
    ajustarTempo = _MockAjustarTempo();
    listarSlots = _MockListarSlots();
    cobrar = _MockCobrar();
    desfazerCobranca = _MockDesfazerCobranca();
    alterarFalta = _MockAlterarFalta();
    remover = _MockRemover();
    obterSaldo = _MockObterSaldo();
    listarServicos = _MockListarServicos();
    when(() => obter(3)).thenAnswer((_) async => Right(_card()));
    when(() => listarEtapas(any())).thenAnswer(
      (_) async => const Right([
        Etapa(id: 1, nome: 'Aguardando'),
        Etapa(id: 2, nome: 'Lavando', ordem: 1),
      ]),
    );
    when(() => obterSaldo(7)).thenAnswer((_) async => Right(_saldo));
  });

  test('carregar traz o card, as etapas e o saldo do cliente', () async {
    final provider = montar();

    await provider.carregar();

    expect(provider.atendimento?.id, 3);
    expect(provider.etapas, hasLength(2));
    expect(provider.saldo, _saldo);
  });

  test(
    'mover e alterarFalta mandam os parâmetros e guardam a resposta',
    () async {
      when(() => mover(any()))
          .thenAnswer((_) async => Right(_card(etapaId: 2)));
      when(() => alterarFalta(any()))
          .thenAnswer((_) async => Right(_card(faltou: true)));
      final provider = montar();
      await provider.carregar();

      await provider.mover(2);
      expect(provider.atendimento?.etapaId, 2);
      final mov =
          verify(() => mover(captureAny())).captured.single
              as MoverAtendimentoParams;
      expect((mov.id, mov.etapaId), (3, 2));

      await provider.alterarFalta(true);
      expect(provider.atendimento?.faltou, isTrue);
      final falta =
          verify(() => alterarFalta(captureAny())).captured.single
              as AlterarFaltaParams;
      expect((falta.id, falta.faltou), (3, true));
    },
  );

  test('falta em atendimento pago vira mensagem e a ficha continua', () async {
    when(() => alterarFalta(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'Esse atendimento já foi cobrado.',
          code: 'falta_em_pago',
        ),
      ),
    );
    final provider = montar();
    await provider.carregar();

    await provider.alterarFalta(true);

    expect(provider.errorMessage, contains('já foi cobrado'));
    expect(provider.atendimento?.faltou, isFalse);
  });

  test('cobrar devolve true e recarrega o saldo; desfazer também', () async {
    when(() => cobrar(any())).thenAnswer((_) async => Right(_card(pago: true)));
    when(() => desfazerCobranca(3)).thenAnswer((_) async => Right(_card()));
    final provider = montar();
    await provider.carregar();

    final ok = await provider.cobrar(
      CobrancaParams(
        id: 3,
        pagamentos: [
          Pagamento(forma: FormaPagamento.pix, valor: Decimal.fromInt(60)),
        ],
      ),
    );

    expect(ok, isTrue);
    expect(provider.atendimento?.pago, isTrue);
    verify(() => obterSaldo(7)).called(2);

    await provider.desfazerCobranca();
    expect(provider.atendimento?.pago, isFalse);
    verify(() => obterSaldo(7)).called(1);
  });

  group('a troca de serviço na cobrança', () {
    final lavagem = Servico(
      id: 3,
      nome: 'Lavagem',
      duracao: 40,
      preco: Decimal.fromInt(60),
    );
    final pesada = Servico(
      id: 8,
      nome: 'Lavagem pesada',
      duracao: 90,
      preco: Decimal.fromInt(120),
    );
    final soMoto = Servico(
      id: 9,
      nome: 'Lavagem · Moto',
      porte: Porte.moto,
      duracao: 20,
      preco: Decimal.fromInt(30),
    );

    setUp(() {
      when(() => listarServicos(any()))
          .thenAnswer((_) async => Right([lavagem, pesada, soMoto]));
    });

    test('sem o catálogo injetado não há para o que trocar', () async {
      final provider = montar();
      await provider.carregar();

      expect(provider.servicosParaTrocar, isEmpty);
      verifyNever(() => listarServicos(any()));
    });

    test('carrega só os ativos e filtra pelo porte do objeto', () async {
      const carro = Veiculo(
        id: 10,
        clienteId: 7,
        placa: 'ABC1D23',
        marca: 'Fiat',
        modelo: 'Uno',
        cor: 'Prata',
        porte: Porte.carro,
      );
      when(() => obter(3)).thenAnswer(
        (_) async => Right(_card(objeto: const ObjetoCliente.veiculo(carro))),
      );
      final provider = montar(comCatalogo: true);
      await provider.carregar();

      final params =
          verify(() => listarServicos(captureAny())).captured.single
              as ListarServicosParams;
      expect(params.ativo, isTrue);
      // o de moto não serve para um carro
      expect(provider.servicosParaTrocar, [lavagem, pesada]);
    });

    test('no avulso não há porte: todos servem', () async {
      when(() => obter(3)).thenAnswer((_) async => Right(_card(objeto: null)));
      final provider = montar(comCatalogo: true);
      await provider.carregar();

      expect(provider.servicosParaTrocar, [lavagem, pesada, soMoto]);
    });

    test('o catálogo falhando não derruba a ficha', () async {
      when(() => listarServicos(any()))
          .thenAnswer((_) async => const Left(NetworkFailure()));
      final provider = montar(comCatalogo: true);
      await provider.carregar();

      expect(provider.atendimento, isNotNull);
      expect(provider.servicosParaTrocar, isEmpty);
    });
  });

  group('avisoDeTempo', () {
    final dia = DateTime(2026, 10, 25);

    test('depois de pronto, passou do tempo do serviço: avisa', () async {
      when(() => obter(3)).thenAnswer(
        (_) async => Right(
          _card(
            data: dia,
            hora: _nove,
            prontoEm: DateTime(2026, 10, 25, 10, 50),
          ),
        ),
      );
      final provider = montar();
      await provider.carregar();

      expect(
        provider.avisoDeTempo,
        'Este atendimento levou 1h50. O previsto era 40 min. Se combinou um '
        'valor a mais com o cliente, inclua abaixo.',
      );
    });

    test('dentro do tempo, ou ainda não pronto, não avisa', () async {
      when(() => obter(3)).thenAnswer(
        (_) async => Right(
          _card(
            data: dia,
            hora: _nove,
            prontoEm: DateTime(2026, 10, 25, 9, 30),
          ),
        ),
      );
      final provider = montar();
      await provider.carregar();
      expect(provider.avisoDeTempo, isNull);

      when(() => obter(3))
          .thenAnswer((_) async => Right(_card(data: dia, hora: _nove)));
      await provider.carregar();
      expect(provider.avisoDeTempo, isNull);
    });

    test(
      'o tempo a mais do pátio não muda a base: o previsto é o do serviço',
      () async {
        when(() => obter(3)).thenAnswer(
          (_) async => Right(
            _card(
              data: dia,
              hora: _nove,
              minutosExtras: 60,
              prontoEm: DateTime(2026, 10, 25, 10, 0),
            ),
          ),
        );
        final provider = montar();
        await provider.carregar();

        expect(
          provider.avisoDeTempo,
          startsWith('Este atendimento levou 1 h.'),
        );
        expect(provider.avisoDeTempo, contains('O previsto era 40 min.'));
      },
    );
  });

  test('remover fecha a ficha', () async {
    when(() => remover(3)).thenAnswer((_) async => const Right(null));
    final provider = montar();
    await provider.carregar();

    await provider.remover();

    expect(provider.removido, isTrue);
  });

  test('ajustarTempo manda os minutos e guarda a resposta', () async {
    when(() => ajustarTempo(any()))
        .thenAnswer((_) async => Right(_card(minutosExtras: 30)));
    final provider = montar();
    await provider.carregar();

    await provider.ajustarTempo(30);

    final params =
        verify(() => ajustarTempo(captureAny())).captured.single
            as AjustarTempoParams;
    expect((params.id, params.minutosExtras), (3, 30));
    expect(provider.atendimento?.minutosExtras, 30);
    expect(provider.atendimento?.duracaoPrevista, 70);
  });

  test('remarcar manda o dia e a hora, guarda a resposta e oferece o aviso '
      'pronto para o WhatsApp', () async {
    when(() => remarcar(any()))
        .thenAnswer((_) async => Right(_card(data: _quinta, hora: _nove)));
    final provider = montar();
    await provider.carregar();

    await provider.remarcar(DateTime(2026, 11, 5, 14), _nove);

    final params =
        verify(() => remarcar(captureAny())).captured.single
            as RemarcarAtendimentoKanbanParams;
    expect(params.id, 3);
    expect(params.data, _quinta);
    expect(params.horarioEntrada, _nove);
    expect(params.ignorarLimite, isFalse);
    expect(provider.remarcado, isTrue);
    expect(
      provider.textoDoAviso,
      'Oi, Ana. Tivemos um imprevisto e o atendimento do Fiat Uno ficou '
      'para quinta, 05/11, às 09:00. Pode ser?',
    );

    provider.avisoOferecido();
    expect(provider.remarcado, isFalse);
  });

  test('textoDoAviso sem hora fala só do dia', () async {
    when(() => obter(3))
        .thenAnswer((_) async => Right(_card(data: DateTime(2026, 11, 7))));
    final provider = montar();
    await provider.carregar();

    expect(
      provider.textoDoAviso,
      endsWith('ficou para sábado, 07/11. Pode ser?'),
    );
  });

  test('dia lotado ao remarcar vira pergunta; aceitar repete com '
      'ignorarLimite', () async {
    when(() => remarcar(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(
          message: 'O dia já está no limite: 8 de 8 atendimentos.',
          code: 'dia_lotado',
        ),
      ),
    );
    final provider = montar();
    await provider.carregar();

    await provider.remarcar(_quinta, null);

    expect(
      provider.limiteEstourado,
      'O dia já está no limite: 8 de 8 atendimentos.',
    );
    expect(provider.errorMessage, isNull);
    expect(provider.remarcado, isFalse);

    when(() => remarcar(any()))
        .thenAnswer((_) async => Right(_card(data: _quinta)));
    await provider.remarcar(_quinta, null, ignorarLimite: true);

    final params =
        verify(() => remarcar(captureAny())).captured.last
            as RemarcarAtendimentoKanbanParams;
    expect(params.ignorarLimite, isTrue);
    expect(provider.limiteEstourado, isNull);
    expect(provider.remarcado, isTrue);
    expect(provider.atendimento?.data, _quinta);
  });

  test('desistir do limite limpa a pergunta; outro erro vai para a '
      'mensagem', () async {
    when(() => remarcar(any())).thenAnswer(
      (_) async => const Left(
        ServerFailure(message: 'Sem vaga nessa hora.', code: 'horario_ocupado'),
      ),
    );
    final provider = montar();
    await provider.carregar();
    await provider.remarcar(_quinta, _nove);
    expect(provider.limiteEstourado, 'Sem vaga nessa hora.');

    provider.desistirDoLimite();
    expect(provider.limiteEstourado, isNull);

    when(() => remarcar(any())).thenAnswer(
      (_) async => const Left(
        ValidationFailure(
          fields: {
            'data': ['Data inválida.'],
          },
        ),
      ),
    );
    await provider.remarcar(_quinta, null);

    expect(provider.errorMessage, 'Data inválida.');
    expect(provider.limiteEstourado, isNull);
    expect(provider.remarcado, isFalse);
  });

  test('slotsParaRemarcar pede a grade do serviço do card; falhou, fica '
      'vazia', () async {
    when(() => listarSlots(any()))
        .thenAnswer((_) async => const Right([_nove]));
    final provider = montar();
    await provider.carregar();

    final slots = await provider.slotsParaRemarcar(_quinta);

    expect(slots, [_nove]);
    final params =
        verify(() => listarSlots(captureAny())).captured.single
            as SlotsKanbanParams;
    expect(params.data, _quinta);
    expect(params.servicoId, 3);

    when(() => listarSlots(any()))
        .thenAnswer((_) async => const Left(NetworkFailure()));
    expect(await provider.slotsParaRemarcar(_quinta), isEmpty);
  });
}
