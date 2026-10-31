import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/clientes/domain/entities/cliente.dart';
import 'package:managers/features/clientes/domain/entities/objeto_cliente.dart';
import 'package:managers/features/clientes/domain/params/listar_clientes_params.dart';
import 'package:managers/features/clientes/domain/usecases/listar_clientes_use_case.dart';
import 'package:managers/features/clientes/domain/usecases/obter_cliente_use_case.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';
import 'package:managers/features/servicos/domain/params/listar_servicos_params.dart';
import 'package:managers/features/servicos/domain/usecases/listar_servicos_use_case.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/listar_colaboradores_use_case.dart';

import '../../domain/entities/atendimento_kanban.dart';
import '../../domain/entities/capacidade_do_dia.dart';
import '../../domain/entities/etapa.dart';
import '../../domain/params/kanban_params.dart';
import '../../domain/usecases/kanban_use_cases.dart';

// estado do formulário de receber um atendimento (montado em
// kanban_provider.dart, na raiz da feature): cliente, o veículo ou pet dele,
// serviço, dia e uma hora de entrada opcional; ou o avulso, só com uma
// identificação e o serviço. os serviços seguem o porte do veículo ou do
// pet; a grade de horas segue a duração do serviço. o card entra na primeira
// etapa do quadro
class AtendimentoKanbanFormProvider extends ChangeNotifier {
  AtendimentoKanbanFormProvider({
    required this._listarEtapas,
    required this._listarServicos,
    required this._listarClientes,
    required this._obterCliente,
    required this._listarSlots,
    required this._listarColaboradores,
    required this._criar,
    required this.tipoObjeto,
    DateTime? dataInicial,
  }) : _data = somenteData(dataInicial ?? DateTime.now());

  final ListarEtapasUseCase _listarEtapas;
  final ListarServicosUseCase _listarServicos;
  final ListarClientesUseCase _listarClientes;
  final ObterClienteUseCase _obterCliente;
  final ListarSlotsKanbanUseCase _listarSlots;
  final ListarColaboradoresUseCase _listarColaboradores;
  final CriarAtendimentoKanbanUseCase _criar;

  // o que o negócio recebe: veículo ou pet
  final TipoObjeto tipoObjeto;

  List<Etapa> _etapas = const [];
  List<Servico> _servicos = const [];
  List<Colaborador> _colaboradores = const [];
  Colaborador? _colaborador;
  bool _carregado = false;
  Failure? _erroAoCarregar;

  bool _avulso = false;
  Cliente? _cliente;
  ObjetoCliente? _objeto;
  Servico? _servico;
  DateTime _data;
  Hora? _hora;
  List<Hora> _slots = const [];
  bool _carregandoSlots = false;
  String? _slotsErrorMessage;

  // cada busca de grade tem um número: a resposta de uma busca antiga, que
  // chega depois, é descartada
  int _buscaDeSlots = 0;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  AtendimentoKanban? _criado;

  // a API recusou por capacidade: a mensagem dela e o code, para a tela
  // perguntar se recebe mesmo assim
  String? _limiteEstourado;
  String? _codeDoLimite;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  // os que servem para o veículo ou pet escolhido: os do porte dele e os
  // sem porte. sem objeto, ou com objeto sem porte, todos; no avulso não há
  // porte, então todos
  List<Servico> get servicos => [
    for (final s in _servicos)
      if (_avulso || s.servePara(_objeto?.porte)) s,
  ];

  // há serviço ativo, mas nenhum para o porte do objeto escolhido
  bool get nenhumServicoParaOPorte =>
      !_avulso && _servicos.isNotEmpty && servicos.isEmpty;

  // o cliente que chegou sem cadastro: só o serviço e uma identificação,
  // sem cliente nem veículo ou pet
  bool get avulso => _avulso;

  bool get carregado => _carregado;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // sem etapas não há onde pôr o card (o onboarding cria as três padrão)
  Etapa? get etapaDeEntrada => _etapas.firstOrNull;

  Cliente? get cliente => _cliente;

  // os veículos ou pets do cliente escolhido
  List<ObjetoCliente> get objetos =>
      _cliente?.objetosDoTipo(tipoObjeto) ?? const [];

  ObjetoCliente? get objeto => _objeto;
  Servico? get servico => _servico;

  // a equipe ativa; o profissional é opcional na esteira
  List<Colaborador> get colaboradores => _colaboradores;
  Colaborador? get colaborador => _colaborador;
  DateTime get data => _data;

  // null: sem hora marcada
  Hora? get hora => _hora;
  List<Hora> get slots => _slots;
  bool get carregandoSlots => _carregandoSlots;
  String? get slotsErrorMessage => _slotsErrorMessage;

  bool get isLoading => _isLoading;

  // erro que não é de campo (rede, regra de negócio)
  String? get errorMessage => _errorMessage;

  // erro de validação da API, campo a campo, com os nomes do contrato
  // (objeto, servico, etapa, data, horario_entrada, observacao)
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  // o dia lotado ou a hora sem vaga (a mensagem da API): a tela pergunta
  // "receber mesmo assim?" e chama salvar com ignorarLimite, ou desiste
  String? get limiteEstourado => _limiteEstourado;

  AtendimentoKanban? get criado => _criado;
  bool get salvo => _criado != null;

  Future<void> carregar() async {
    _erroAoCarregar = null;
    notifyListeners();

    final (etapas, servicos, colaboradores) = await (
      _listarEtapas(NoParams()),
      _listarServicos(const ListarServicosParams(ativo: true)),
      _listarColaboradores(NoParams()),
    ).wait;
    if (_disposed) return;

    etapas.fold((failure) => _erroAoCarregar = failure, (lista) {
      _etapas = lista;
    });
    servicos.fold((failure) => _erroAoCarregar ??= failure, (lista) {
      _servicos = lista;
    });
    // sem a equipe o formulário continua útil: só fica sem o profissional
    colaboradores.fold((_) {}, (lista) {
      _colaboradores = lista.where((c) => c.ativo).toList();
    });

    _carregado = _erroAoCarregar == null;
    notifyListeners();
    if (_carregado) await _carregarSlots();
  }

  // a busca do seletor de cliente: a primeira página basta para escolher
  Future<List<Cliente>> buscarClientes(String busca) async {
    final result = await _listarClientes(ListarClientesParams(busca: busca));
    return result.fold((_) => const [], (pagina) => pagina.itens);
  }

  // liga e desliga o avulso. ligado, o cliente e o objeto escolhidos ficam
  // guardados mas não vão; desligado, o porte volta a valer e o serviço que
  // não serve sai
  void alternarAvulso(bool avulso) {
    if (avulso == _avulso) return;
    _avulso = avulso;
    _fieldErrors = {..._fieldErrors}
      ..remove('objeto')
      ..remove('identificacao');
    if (!avulso) _soltarServicoQueNaoServe();
    notifyListeners();
  }

  void selecionarCliente(Cliente cliente) {
    _cliente = cliente;
    // com um objeto só, ele já fica escolhido
    final objetos = this.objetos;
    _objeto = objetos.length == 1 ? objetos.single : null;
    _soltarServicoQueNaoServe();
    _fieldErrors = {..._fieldErrors}..remove('objeto');
    notifyListeners();
  }

  // a folha cadastrou ou corrigiu um veículo ou pet: o cliente vem da API de
  // novo. o objeto escolhido continua (com o cadastro novo); sem ele, o mais
  // novo fica escolhido
  Future<void> recarregarCliente() async {
    final cliente = _cliente;
    if (cliente == null) return;
    final result = await _obterCliente(cliente.id);
    if (_disposed) return;
    result.fold((_) {}, (c) {
      _cliente = c;
      final objetos = this.objetos;
      _objeto = objetos.isEmpty
          ? null
          : objetos.where((o) => o.id == _objeto?.id).firstOrNull ??
                objetos.reduce((a, b) => a.id >= b.id ? a : b);
      _soltarServicoQueNaoServe();
    });
    notifyListeners();
  }

  void selecionarObjeto(ObjetoCliente? objeto) {
    _objeto = objeto;
    _soltarServicoQueNaoServe();
    _fieldErrors = {..._fieldErrors}..remove('objeto');
    notifyListeners();
  }

  // trocar o veículo ou pet (ou o porte dele) pode deixar o serviço
  // escolhido de fora: ele sai, e a pessoa escolhe entre os que servem. a
  // grade era a dele: vem de novo. no avulso não há porte para conferir
  void _soltarServicoQueNaoServe() {
    if (_avulso) return;
    final servico = _servico;
    if (servico != null && !servico.servePara(_objeto?.porte)) {
      _servico = null;
      _carregarSlots();
    }
  }

  void selecionarColaborador(Colaborador? colaborador) {
    _colaborador = colaborador;
    _fieldErrors = {..._fieldErrors}..remove('colaborador');
    notifyListeners();
  }

  // a grade é do serviço: só as horas em que a duração dele cabe. a hora
  // escolhida que não estiver mais na grade é limpa
  void selecionarServico(Servico? servico) {
    final mudou = servico?.id != _servico?.id;
    _servico = servico;
    _fieldErrors = {..._fieldErrors}..remove('servico');
    notifyListeners();
    if (mudou) _carregarSlots();
  }

  void selecionarData(DateTime data) {
    final nova = somenteData(data);
    if (mesmoDia(nova, _data)) return;
    _data = nova;
    _hora = null;
    _fieldErrors = {..._fieldErrors}..remove('data');
    notifyListeners();
    _carregarSlots();
  }

  void selecionarHora(Hora? hora) {
    _hora = hora;
    _fieldErrors = {..._fieldErrors}..remove('horario_entrada');
    notifyListeners();
  }

  Future<void> recarregarGrade() => _carregarSlots();

  Future<void> _carregarSlots() async {
    final busca = ++_buscaDeSlots;
    _carregandoSlots = true;
    _slotsErrorMessage = null;
    notifyListeners();

    final result = await _listarSlots(
      SlotsKanbanParams(data: _data, servicoId: _servico?.id),
    );
    if (_disposed || busca != _buscaDeSlots) return;

    result.fold((failure) => _slotsErrorMessage = failure.message, (slots) {
      _slots = slots;
      // a hora escolhida pode ter sido tomada, ou o serviço novo não cabe
      // nela
      if (_hora != null && !slots.contains(_hora)) _hora = null;
    });

    _carregandoSlots = false;
    notifyListeners();
  }

  // a tela já conferiu que cliente, objeto e serviço existem (no avulso, a
  // identificação e o serviço). com ignorarLimite, o dono recebe mesmo com
  // o dia lotado ou sem vaga na hora
  Future<void> salvar({
    String observacao = '',
    String identificacao = '',
    bool ignorarLimite = false,
  }) async {
    final objetoId = _avulso ? null : _objeto?.id;
    final texto = _avulso ? identificacao.trim() : '';
    final servico = _servico;
    final etapa = etapaDeEntrada;
    if (servico == null || (_avulso ? texto.isEmpty : objetoId == null)) {
      return;
    }
    if (etapa == null) {
      _errorMessage =
          'O quadro não tem etapas. Cadastre em Mais › Configurações › '
          'Etapas do quadro.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _limiteEstourado = null;
    _codeDoLimite = null;
    _fieldErrors = const {};
    notifyListeners();

    final result = await _criar(
      NovoAtendimentoParams(
        etapaId: etapa.id,
        objetoId: objetoId,
        identificacao: texto,
        servicoId: servico.id,
        data: _data,
        horarioEntrada: _hora,
        colaboradorId: _colaborador?.id,
        observacao: observacao,
        ignorarLimite: ignorarLimite,
      ),
    );
    if (_disposed) return;

    result.fold(
      (failure) {
        if (!ignorarLimite && passaDoLimite(failure)) {
          // para o negócio o limite é aviso: a tela pergunta
          _limiteEstourado = failure.message;
          _codeDoLimite = failure.code;
        } else if (failure.code == 'horario_bloqueado') {
          // o horário fechado não tem "mesmo assim": o dono reabre antes.
          // a hora sai e a grade vem de novo, já sem ela
          _errorMessage = failure.message;
          _hora = null;
          _carregarSlots();
        } else if (failure is ValidationFailure && failure.fields.isNotEmpty) {
          _fieldErrors = {
            for (final e in failure.fields.entries)
              if (e.value.isNotEmpty) e.key: e.value.first,
          };
        } else {
          _errorMessage = failure.message;
        }
      },
      (criado) {
        _criado = criado;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  // a pessoa não quis passar do limite. se era a hora sem vaga, ela sai e
  // a grade vem de novo (alguém tomou a hora enquanto a tela estava aberta)
  void desistirDoLimite() {
    final naHora = _codeDoLimite == 'horario_ocupado';
    _limiteEstourado = null;
    _codeDoLimite = null;
    if (naHora) {
      _hora = null;
      _carregarSlots();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
