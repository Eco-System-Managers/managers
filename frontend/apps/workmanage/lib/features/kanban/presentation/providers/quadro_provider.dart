import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/agenda/domain/entities/bloqueio.dart';
import 'package:managers/features/agenda/domain/usecases/agenda_use_cases.dart'
    show
        ExcluirBloqueioUseCase,
        ListarAgendamentosDoDiaParams,
        ListarBloqueiosDoDiaUseCase,
        ListarPendenciasUseCase;

import '../../domain/entities/atendimento_kanban.dart';
import '../../domain/entities/capacidade_do_dia.dart';
import '../../domain/entities/etapa.dart';
import '../../domain/params/kanban_params.dart';
import '../../domain/usecases/kanban_use_cases.dart';

// estado do quadro (montado em kanban_provider.dart, na raiz da feature): o
// dia escolhido, as etapas e os cards de cada uma, quanto cabe no dia, os
// horários fechados do negócio nele e quantas cobranças estão pendentes (as
// pendências e os bloqueios são os da agenda: a API junta os dois modos). o
// quadro é um só, do negócio: não há recorte por pessoa
class QuadroProvider extends ChangeNotifier {
  QuadroProvider({
    required this._listarEtapas,
    required this._listarDoDia,
    required this._mover,
    required this._listarPendencias,
    required this._obterCapacidade,
    required this._ajustarCapacidade,
    required this._desfazerAjuste,
    required this._listarBloqueios,
    required this._excluirBloqueio,
    bool Function()? operaComODono,
    bool Function()? soMoveOsCards,
    DateTime? hoje,
  }) : _operaComODono = operaComODono ?? (() => false),
       _soMoveOsCards = soMoveOsCards ?? (() => false),
       _hoje = somenteData(hoje ?? DateTime.now()),
       _dia = somenteData(hoje ?? DateTime.now());

  // quem entrou, lido na hora, porque o negócio atual carrega depois do
  // login. o dono e o parceiro operam o quadro (recebem, ajustam o dia e
  // fecham horários); o colaborador comum só move os cards e ajusta o tempo
  final bool Function() _operaComODono;
  final bool Function() _soMoveOsCards;
  bool get operaComODono => _operaComODono();
  bool get soMoveOsCards => _soMoveOsCards();

  final ListarEtapasUseCase _listarEtapas;
  final ListarAtendimentosDoDiaUseCase _listarDoDia;
  final MoverAtendimentoUseCase _mover;
  final ListarPendenciasUseCase _listarPendencias;
  final ObterCapacidadeDoDiaUseCase _obterCapacidade;
  final AjustarCapacidadeDoDiaUseCase _ajustarCapacidade;
  final DesfazerAjusteDoDiaUseCase _desfazerAjuste;
  final ListarBloqueiosDoDiaUseCase _listarBloqueios;
  final ExcluirBloqueioUseCase _excluirBloqueio;

  final DateTime _hoje;
  DateTime _dia;
  List<Etapa> _etapas = const [];
  List<AtendimentoKanban> _atendimentos = const [];
  CapacidadeDoDia? _capacidade;
  List<Bloqueio> _bloqueios = const [];
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  int _pendencias = 0;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  DateTime get hoje => _hoje;
  DateTime get dia => _dia;
  bool get ehHoje => mesmoDia(_dia, _hoje);
  List<Etapa> get etapas => _etapas;
  List<AtendimentoKanban> get atendimentos => _atendimentos;

  // quanto cabe no dia aberto e quanto já há nele; null quando a consulta
  // falhou (o quadro continua, só sem o resumo)
  CapacidadeDoDia? get capacidade => _capacidade;

  // os horários fechados do negócio inteiro que valem no dia aberto, na
  // ordem da hora (o dia todo primeiro). os bloqueios por profissional da
  // agenda ficam de fora: na esteira a capacidade é do negócio
  List<Bloqueio> get bloqueios => _bloqueios;
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro de uma ação (mover); o quadro continua
  String? get errorMessage => _errorMessage;

  // atendimentos passados sem cobrança; 0 também quando a consulta falhou
  // ou quando quem entrou não cobra (o colaborador comum da esteira)
  int get pendencias => _pendencias;

  // os cards de uma coluna: quem tem hora marcada primeiro, na ordem da
  // hora; depois os sem hora, na ordem de chegada
  List<AtendimentoKanban> naEtapa(int etapaId) {
    final cards = _atendimentos.where((a) => a.etapaId == etapaId).toList();
    cards.sort((a, b) {
      final ha = a.horarioEntrada;
      final hb = b.horarioEntrada;
      if (ha != null && hb != null) {
        final porHora = (ha.hora * 60 + ha.minuto).compareTo(
          hb.hora * 60 + hb.minuto,
        );
        if (porHora != 0) return porHora;
      } else if (ha != null) {
        return -1;
      } else if (hb != null) {
        return 1;
      }
      return a.id.compareTo(b.id);
    });
    return cards;
  }

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final (etapas, dia, capacidade, bloqueios, _) = await (
      _listarEtapas(NoParams()),
      _listarDoDia(ListarDoDiaParams(data: _dia)),
      _obterCapacidade(_dia),
      _listarBloqueios(ListarAgendamentosDoDiaParams(data: _dia)),
      _carregarPendencias(),
    ).wait;
    if (_disposed) return;

    etapas.fold((failure) => _erroAoCarregar = failure, (lista) {
      _etapas = lista;
    });
    dia.fold((failure) => _erroAoCarregar ??= failure, (lista) {
      _atendimentos = lista;
    });
    if (_erroAoCarregar == null) _carregado = true;
    // sem a capacidade o quadro continua útil: só fica sem o resumo
    capacidade.fold((_) => _capacidade = null, (c) => _capacidade = c);
    // sem os bloqueios também: a grade de horas já vem sem eles da API, o
    // quadro só deixa de mostrar as faixas fechadas
    bloqueios.fold((_) => _bloqueios = const [], (lista) {
      _bloqueios = _ordenados([
        for (final b in lista)
          if (b.doNegocio) b,
      ]);
    });

    _isLoading = false;
    notifyListeners();
  }

  // o colaborador comum da esteira não cobra: as pendências não são dele (a
  // API recusa), então nem são pedidas
  Future<void> _carregarPendencias() async {
    if (soMoveOsCards) return;
    final result = await _listarPendencias(NoParams());
    result.fold((_) {}, (lista) => _pendencias = lista.length);
  }

  Future<void> selecionarDia(DateTime data) async {
    final novo = somenteData(data);
    if (mesmoDia(novo, _dia)) return;
    _dia = novo;
    notifyListeners();
    await carregar();
  }

  Future<void> irParaHoje() => selecionarDia(_hoje);

  // o dia todo antes das faixas; as faixas pela hora de início
  static List<Bloqueio> _ordenados(List<Bloqueio> lista) {
    int minutos(Bloqueio b) =>
        b.diaInteiro ? -1 : b.horaInicio!.hora * 60 + b.horaInicio!.minuto;
    return lista..sort((a, b) => minutos(a).compareTo(minutos(b)));
  }

  // ao voltar de uma tela que pode ter mudado o quadro
  Future<void> recarregar() => carregar();

  // reabre um horário fechado do negócio (o dono e o parceiro). devolve a
  // mensagem de erro para a folha mostrar, ou null quando excluiu (e o dia
  // recarrega: a grade de horas muda junto)
  Future<String?> excluirBloqueio(int id) async {
    final result = await _excluirBloqueio(id);
    if (_disposed) return null;
    final erro = result.fold((failure) => failure.message, (_) => null);
    if (erro == null) await carregar();
    return erro;
  }

  // o card muda de coluna e o quadro é relido da API
  Future<void> mover(int id, int etapaId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _mover(
      MoverAtendimentoParams(id: id, etapaId: etapaId),
    );
    if (_disposed) return;

    await result.fold((failure) async {
      _errorMessage = failure.message;
      _isLoading = false;
      notifyListeners();
    }, (_) => carregar());
  }

  // o ajuste do dia aberto (o dono e o parceiro). devolve a mensagem de erro
  // para a folha mostrar, ou null quando salvou; a capacidade já fica a
  // que a API devolveu
  Future<String?> ajustarCapacidade({int? capacidade, required int vagas}) {
    return _mudarCapacidade(
      () => _ajustarCapacidade(
        AjustarCapacidadeParams(
          data: _dia,
          capacidade: capacidade,
          vagas: vagas,
        ),
      ),
    );
  }

  // apaga o ajuste do dia aberto: volta ao padrão da semana
  Future<String?> voltarAoPadrao() =>
      _mudarCapacidade(() => _desfazerAjuste(_dia));

  Future<String?> _mudarCapacidade(
    Future<Either<Failure, CapacidadeDoDia>> Function() acao,
  ) async {
    final result = await acao();
    if (_disposed) return null;
    return result.fold(
      (failure) =>
          failure is ValidationFailure ? failure.resumo : failure.message,
      (c) {
        _capacidade = c;
        notifyListeners();
        return null;
      },
    );
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
