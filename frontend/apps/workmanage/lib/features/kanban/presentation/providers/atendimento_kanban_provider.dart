import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/core/utils/texto.dart';
import 'package:managers/features/financeiro/domain/entities/saldo_cliente.dart';
import 'package:managers/features/financeiro/domain/params/cobranca_params.dart';
import 'package:managers/features/financeiro/domain/usecases/financeiro_use_cases.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';
import 'package:managers/features/servicos/domain/params/listar_servicos_params.dart';
import 'package:managers/features/servicos/domain/usecases/listar_servicos_use_case.dart';

import '../../domain/entities/atendimento_kanban.dart';
import '../../domain/entities/capacidade_do_dia.dart';
import '../../domain/entities/etapa.dart';
import '../../domain/params/kanban_params.dart';
import '../../domain/usecases/kanban_use_cases.dart';

// estado de um card aberto (montado em kanban_provider.dart, na raiz da
// feature): a ficha e as ações sobre ele. toda ação devolve o atendimento
// como a API o deixou. com o card atrasado, o quadro do dia vem junto, para
// mostrar quem vem depois
class AtendimentoKanbanProvider extends ChangeNotifier {
  AtendimentoKanbanProvider({
    required this.id,
    required this._obter,
    required this._listarEtapas,
    required this._listarDoDia,
    required this._mover,
    required this._remarcar,
    required this._ajustarTempo,
    required this._listarSlots,
    required this._cobrar,
    required this._desfazerCobranca,
    required this._alterarFalta,
    required this._remover,
    required this._obterSaldo,
    this._listarServicos,
    DateTime Function()? agora,
  }) : _agora = agora ?? DateTime.now;

  final int id;
  final ObterAtendimentoKanbanUseCase _obter;
  final ListarEtapasUseCase _listarEtapas;
  final ListarAtendimentosDoDiaUseCase _listarDoDia;
  final MoverAtendimentoUseCase _mover;
  final RemarcarAtendimentoKanbanUseCase _remarcar;
  final AjustarTempoAtendimentoUseCase _ajustarTempo;
  final ListarSlotsKanbanUseCase _listarSlots;
  final CobrarAtendimentoKanbanUseCase _cobrar;
  final DesfazerCobrancaUseCase _desfazerCobranca;
  final AlterarFaltaUseCase _alterarFalta;
  final RemoverAtendimentoKanbanUseCase _remover;
  final ObterSaldoClienteUseCase _obterSaldo;

  // o catálogo, para a cobrança trocar o serviço pelo que foi feito de
  // verdade. opcional: sem ele a cobrança não oferece a troca
  final ListarServicosUseCase? _listarServicos;

  // o relógio, trocável nos testes
  final DateTime Function() _agora;

  AtendimentoKanban? _atendimento;
  List<Etapa> _etapas = const [];
  List<Servico> _servicos = const [];
  SaldoCliente? _saldo;
  List<AtendimentoKanban> _doDia = const [];
  bool _diaCarregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  bool _removido = false;
  bool _remarcado = false;

  // a API recusou remarcar por capacidade: a mensagem dela, para a tela
  // perguntar se remarca mesmo assim
  String? _limiteEstourado;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  AtendimentoKanban? get atendimento => _atendimento;

  // as colunas, para "mover para"
  List<Etapa> get etapas => _etapas;

  // o crédito do cliente na comanda; null quando a consulta falhou ou no
  // avulso, que não tem comanda
  SaldoCliente? get saldo => _saldo;

  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro de uma ação; a ficha continua
  String? get errorMessage => _errorMessage;

  // true depois de excluir: a tela fecha
  bool get removido => _removido;

  // true depois de remarcar nesta ficha: a tela oferece avisar o cliente
  bool get remarcado => _remarcado;

  // o dia lotado ou a hora sem vaga no destino (a mensagem da API): a tela
  // pergunta "remarcar mesmo assim?" e repete com ignorarLimite, ou desiste
  String? get limiteEstourado => _limiteEstourado;

  // quantos minutos o card passou do fim previsto, agora; 0 sem atraso
  int get atraso => _atendimento?.atrasoEm(_agora()) ?? 0;

  // os serviços pelos quais a cobrança pode trocar o combinado: os ativos
  // que servem para o porte do veículo ou pet (a API recusa os outros com
  // servico_de_outro_porte); no avulso não há porte, então todos. vazio sem
  // catálogo carregado
  List<Servico> get servicosParaTrocar {
    final a = _atendimento;
    if (a == null) return const [];
    return [
      for (final s in _servicos)
        if (a.ehAvulso || s.servePara(a.objeto?.porte)) s,
    ];
  }

  // o aviso da cobrança quando o atendimento levou mais que o tempo do
  // serviço: "Este atendimento levou 1h50. O previsto era 40 min. ...". só
  // depois de pronto (é daí que sai o tempo real) e só se passou. a base é
  // a duração do serviço, não o tempo a mais do pátio: o preço é do serviço
  String? get avisoDeTempo {
    final a = _atendimento;
    final levou = a?.minutosLevados;
    if (a == null || levou == null) return null;
    final previsto = a.servicoDuracao;
    if (previsto <= 0 || levou <= previsto) return null;
    return 'Este atendimento levou ${formatarDuracao(levou)}. O previsto era '
        '${formatarDuracao(previsto)}. Se combinou um valor a mais com o '
        'cliente, inclua abaixo.';
  }

  // quem vem depois deste card no mesmo dia e ainda não está pronto, na
  // ordem da hora de entrada: os afetados pelo atraso. quem faltou não vem
  // mais, e sem hora marcada não há horário para avisar. vazio sem atraso
  List<AtendimentoKanban> get afetados {
    final a = _atendimento;
    final inicio = a?.inicioPrevisto;
    if (a == null || inicio == null || atraso <= 0) return const [];
    final lista = [
      for (final o in _doDia)
        if (o.id != a.id &&
            !o.pronto &&
            !o.faltou &&
            o.horarioEntrada != null &&
            (o.inicioPrevisto?.isAfter(inicio) ?? false))
          o,
    ];
    lista.sort((x, y) => x.inicioPrevisto!.compareTo(y.inicioPrevisto!));
    return lista;
  }

  // o aviso do atraso para um afetado: "Oi, Paulo! Tivemos um atraso aqui e
  // o seu horário das 10:00 deve atrasar uns 30 min. Tudo bem?". null sem
  // telefone, sem hora ou sem atraso
  String? textoDoAtraso(AtendimentoKanban afetado) {
    final hora = afetado.horarioEntrada;
    final minutos = atraso;
    if (hora == null || afetado.clienteTelefone.isEmpty || minutos <= 0) {
      return null;
    }
    final nome = primeiroNome(afetado.clienteNome);
    return '${nome.isEmpty ? 'Oi!' : 'Oi, $nome!'} Tivemos um atraso aqui e '
        'o seu horário das ${formatarHora(hora)} deve atrasar uns '
        '${formatarDuracao(minutos)}. Tudo bem?';
  }

  // o aviso pronto para o WhatsApp depois de remarcar: "Oi, Ana. Tivemos um
  // imprevisto e o atendimento do Fiat Uno ficou para quinta, 05/11, às
  // 09:00. Pode ser?" (sem hora, só o dia). null sem atendimento, sem dia
  // ou no avulso, que não tem cliente para avisar
  String? get textoDoAviso {
    final a = _atendimento;
    final data = a?.data;
    if (a == null || data == null || a.ehAvulso) return null;
    final hora = a.horarioEntrada;
    final quando =
        '${nomeDoDiaDaSemana(data)}, ${formatarData(data).substring(0, 5)}'
        '${hora == null ? '' : ', às ${formatarHora(hora)}'}';
    return 'Oi, ${primeiroNome(a.clienteNome)}. Tivemos um imprevisto e o '
        'atendimento do ${a.titulo} ficou para $quando. Pode ser?';
  }

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final (atendimento, etapas, _) = await (
      _obter(id),
      _listarEtapas(NoParams()),
      _carregarServicos(),
    ).wait;
    if (_disposed) return;

    etapas.fold((_) {}, (lista) => _etapas = lista);
    await atendimento.fold((failure) async => _erroAoCarregar = failure, (
      a,
    ) async {
      _atendimento = a;
      await (_carregarSaldo(a), _carregarDia(a)).wait;
    });
    if (_disposed) return;

    _isLoading = false;
    notifyListeners();
  }

  // o catálogo ativo, para a troca na cobrança. falhou (ou não há use case),
  // a ficha segue sem a troca
  Future<void> _carregarServicos() async {
    final listar = _listarServicos;
    if (listar == null) return;
    final result = await listar(const ListarServicosParams(ativo: true));
    result.fold((_) {}, (lista) => _servicos = lista);
  }

  // a comanda é do cliente: o avulso não tem
  Future<void> _carregarSaldo(AtendimentoKanban a) async {
    final clienteId = a.clienteId;
    if (clienteId == null) {
      _saldo = null;
      return;
    }
    final result = await _obterSaldo(clienteId);
    result.fold((_) => _saldo = null, (s) => _saldo = s);
  }

  // o quadro do dia, só com o card atrasado: é dele que saem os afetados.
  // falhou, a ficha continua sem a lista
  Future<void> _carregarDia(AtendimentoKanban a) async {
    final dia = a.data ?? a.inicioPrevisto;
    if (dia == null || a.atrasoEm(_agora()) <= 0) return;
    final result = await _listarDoDia(
      ListarDoDiaParams(data: somenteData(dia)),
    );
    result.fold((_) {}, (lista) {
      _doDia = lista;
      _diaCarregado = true;
    });
  }

  Future<void> mover(int etapaId) =>
      _executar(() => _mover(MoverAtendimentoParams(id: id, etapaId: etapaId)));

  Future<void> alterarFalta(bool faltou) => _executar(
    () => _alterarFalta(AlterarFaltaParams(id: id, faltou: faltou)),
  );

  // o tempo a mais previsto (0 tira). não é barrado e não mexe no preço
  Future<void> ajustarTempo(int minutosExtras) => _executar(
    () =>
        _ajustarTempo(AjustarTempoParams(id: id, minutosExtras: minutosExtras)),
  );

  // a grade para remarcar: as horas em que este serviço cabe em outro dia,
  // sem contar o próprio card (no mesmo dia ele barraria a si mesmo).
  // falhou, fica sem grade (a pessoa ainda remarca sem hora)
  Future<List<Hora>> slotsParaRemarcar(DateTime data) async {
    final servicoId = _atendimento?.servicoId;
    if (servicoId == null) return const [];
    final result = await _listarSlots(
      SlotsKanbanParams(data: data, servicoId: servicoId, excluirId: id),
    );
    return result.fold((_) => const [], (slots) => slots);
  }

  // outro dia e outra hora (ou sem hora). o dia lotado ou a hora sem vaga
  // viram pergunta; com ignorarLimite o dono remarca mesmo assim
  Future<void> remarcar(
    DateTime data,
    Hora? hora, {
    bool ignorarLimite = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _limiteEstourado = null;
    notifyListeners();

    final result = await _remarcar(
      RemarcarAtendimentoKanbanParams(
        id: id,
        data: somenteData(data),
        horarioEntrada: hora,
        ignorarLimite: ignorarLimite,
      ),
    );
    if (_disposed) return;

    result.fold(
      (failure) {
        if (!ignorarLimite && passaDoLimite(failure)) {
          _limiteEstourado = failure.message;
        } else {
          _errorMessage = failure is ValidationFailure
              ? failure.resumo
              : failure.message;
        }
      },
      (a) {
        _atendimento = a;
        _remarcado = true;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  // a pessoa não quis passar do limite: nada muda
  void desistirDoLimite() {
    if (_limiteEstourado == null) return;
    _limiteEstourado = null;
    notifyListeners();
  }

  // a tela já ofereceu o aviso (ou a pessoa fechou): não oferece de novo
  void avisoOferecido() {
    if (!_remarcado) return;
    _remarcado = false;
    notifyListeners();
  }

  // devolve true quando cobrou: a folha de cobrança fecha
  Future<bool> cobrar(CobrancaParams params) async {
    await _executar(() => _cobrar(params));
    if (_errorMessage != null) return false;
    await _atualizarSaldo();
    return true;
  }

  Future<void> desfazerCobranca() async {
    await _executar(() => _desfazerCobranca(id));
    if (_errorMessage == null) await _atualizarSaldo();
  }

  // o troco e o crédito aplicado mudam a comanda
  Future<void> _atualizarSaldo() async {
    final a = _atendimento;
    if (a == null || a.clienteId == null) return;
    await _carregarSaldo(a);
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> remover() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _remover(id);
    if (_disposed) return;

    result.fold(
      (failure) => _errorMessage = failure.message,
      (_) => _removido = true,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _executar(
    Future<Either<Failure, AtendimentoKanban>> Function() acao,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await acao();
    if (_disposed) return;

    await result.fold((failure) async => _errorMessage = failure.message, (
      a,
    ) async {
      _atendimento = a;
      // a ação pode ter deixado o card atrasado (saiu de pronto, por
      // exemplo) e o dia ainda não veio
      if (!_diaCarregado) await _carregarDia(a);
    });
    if (_disposed) return;

    _isLoading = false;
    notifyListeners();
  }

  void limparErro() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
