import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/core/utils/datas.dart';
import 'package:managers/features/clientes/domain/entities/cliente.dart';
import 'package:managers/features/clientes/domain/params/listar_clientes_params.dart';
import 'package:managers/features/clientes/domain/usecases/listar_clientes_use_case.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';
import 'package:managers/features/servicos/domain/params/listar_servicos_params.dart';
import 'package:managers/features/servicos/domain/usecases/listar_servicos_use_case.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/listar_colaboradores_use_case.dart';

import '../../domain/entities/agendamento.dart';
import '../../domain/entities/slot.dart';
import '../../domain/params/agenda_params.dart';
import '../../domain/usecases/agenda_use_cases.dart';

// estado do formulário de agendamento novo (montado em agenda_provider.dart,
// na raiz da feature): cliente, serviço, profissional, dia e horário. o
// horário vem da grade da API, que já desconta a duração do serviço e a
// agenda do profissional; por isso a grade recarrega a cada escolha
class AgendamentoFormProvider extends ChangeNotifier {
  AgendamentoFormProvider({
    required this._listarServicos,
    required this._listarColaboradores,
    required this._listarClientes,
    required this._listarSlots,
    required this._criar,
    this.colaboradorInicialId,
    this.horaInicial,
    DateTime? dataInicial,
  }) : _data = somenteData(dataInicial ?? DateTime.now());

  final ListarServicosUseCase _listarServicos;
  final ListarColaboradoresUseCase _listarColaboradores;
  final ListarClientesUseCase _listarClientes;
  final ListarSlotsUseCase _listarSlots;
  final CriarAgendamentoUseCase _criar;

  // quem está logado: começa selecionado quando faz parte da equipe
  final int? colaboradorInicialId;

  // a hora tocada na grade: entra escolhida assim que a grade de slots
  // chegar, se ainda estiver livre
  final Hora? horaInicial;
  bool _horaInicialAplicada = false;

  List<Servico> _servicos = const [];
  List<Colaborador> _colaboradores = const [];
  bool _carregado = false;
  Failure? _erroAoCarregar;

  Cliente? _cliente;
  Servico? _servico;
  Colaborador? _colaborador;
  DateTime _data;
  Hora? _hora;
  List<Slot> _slots = const [];
  bool _carregandoSlots = false;
  String? _slotsErrorMessage;

  // cada busca de grade tem um número: a resposta de uma busca antiga, que
  // chega depois, é descartada
  int _buscaDeSlots = 0;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  Agendamento? _criado;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  // os serviços que o profissional escolhido faz. serviço sem executor
  // marcado é de qualquer um, então fica sempre
  List<Servico> get servicos {
    final id = _colaborador?.id;
    if (id == null) return _servicos;
    return _servicos
        .where((s) => s.colaboradores.isEmpty || s.colaboradores.contains(id))
        .toList();
  }

  // a equipe ativa. com serviço escolhido que tem executores marcados, só eles
  List<Colaborador> get colaboradores {
    final executores = _servico?.colaboradores ?? const [];
    if (executores.isEmpty) return _colaboradores;
    return _colaboradores.where((c) => executores.contains(c.id)).toList();
  }

  bool get carregado => _carregado;
  Failure? get erroAoCarregar => _erroAoCarregar;

  Cliente? get cliente => _cliente;
  Servico? get servico => _servico;
  Colaborador? get colaborador => _colaborador;
  DateTime get data => _data;
  Hora? get hora => _hora;
  List<Slot> get slots => _slots;
  bool get carregandoSlots => _carregandoSlots;
  String? get slotsErrorMessage => _slotsErrorMessage;

  // a grade só existe com serviço, profissional e dia escolhidos
  bool get prontoParaGrade => _servico != null && _colaborador != null;

  bool get isLoading => _isLoading;

  // erro que não é de campo (rede, conflito de horário)
  String? get errorMessage => _errorMessage;

  // erro de validação da API, campo a campo, com os nomes do contrato
  // (cliente, servico_id, colaborador, data_hora, observacoes)
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  // o agendamento criado; a tela fecha quando ele chega
  Agendamento? get criado => _criado;
  bool get salvo => _criado != null;

  Future<void> carregar() async {
    _erroAoCarregar = null;
    notifyListeners();

    final (servicos, colaboradores) = await (
      _listarServicos(const ListarServicosParams(ativo: true)),
      _listarColaboradores(NoParams()),
    ).wait;
    if (_disposed) return;

    servicos.fold((failure) => _erroAoCarregar = failure, (lista) {
      _servicos = lista;
    });
    colaboradores.fold((failure) => _erroAoCarregar ??= failure, (lista) {
      _colaboradores = lista.where((c) => c.ativo).toList();
      _colaborador = _colaboradores
          .where((c) => c.id == colaboradorInicialId)
          .firstOrNull;
    });

    _carregado = _erroAoCarregar == null;
    notifyListeners();
  }

  // a busca do seletor de cliente: a primeira página basta para escolher
  Future<List<Cliente>> buscarClientes(String busca) async {
    final result = await _listarClientes(ListarClientesParams(busca: busca));
    return result.fold((_) => const [], (pagina) => pagina.itens);
  }

  void selecionarCliente(Cliente cliente) {
    _cliente = cliente;
    _fieldErrors = {..._fieldErrors}..remove('cliente');
    notifyListeners();
  }

  void selecionarServico(Servico? servico) {
    if (servico == _servico) return;
    _servico = servico;
    // o executor atual pode não fazer este serviço
    if (_colaborador != null && !colaboradores.contains(_colaborador)) {
      _colaborador = null;
    }
    _fieldErrors = {..._fieldErrors}..remove('servico_id');
    _recarregarGrade();
  }

  void selecionarColaborador(Colaborador? colaborador) {
    if (colaborador == _colaborador) return;
    _colaborador = colaborador;
    // o serviço atual pode não ser deste profissional
    if (_servico != null && !servicos.contains(_servico)) {
      _servico = null;
    }
    _fieldErrors = {..._fieldErrors}..remove('colaborador');
    _recarregarGrade();
  }

  void selecionarData(DateTime data) {
    final nova = somenteData(data);
    if (mesmoDia(nova, _data)) return;
    _data = nova;
    _recarregarGrade();
  }

  void selecionarHora(Hora? hora) {
    _hora = hora;
    _fieldErrors = {..._fieldErrors}..remove('data_hora');
    notifyListeners();
  }

  // mudou o que define a grade: a hora escolhida pode não existir mais
  void _recarregarGrade() {
    _hora = null;
    _slots = const [];
    _slotsErrorMessage = null;
    final servico = _servico;
    final colaborador = _colaborador;
    if (servico == null || colaborador == null) {
      notifyListeners();
      return;
    }
    _carregarSlots(servico.id, colaborador.id);
  }

  Future<void> _carregarSlots(int servicoId, int colaboradorId) async {
    final busca = ++_buscaDeSlots;
    _carregandoSlots = true;
    notifyListeners();

    final result = await _listarSlots(
      SlotsParams(
        data: _data,
        servicoId: servicoId,
        colaboradorId: colaboradorId,
      ),
    );
    if (_disposed || busca != _buscaDeSlots) return;

    result.fold((failure) => _slotsErrorMessage = failure.message, (slots) {
      _slots = slots;
      if (!_horaInicialAplicada && horaInicial != null) {
        _horaInicialAplicada = true;
        final livre = slots.any((s) => s.hora == horaInicial && s.disponivel);
        if (livre) _hora = horaInicial;
      }
    });

    _carregandoSlots = false;
    notifyListeners();
  }

  Future<void> recarregarGrade() async {
    final servico = _servico;
    final colaborador = _colaborador;
    if (servico == null || colaborador == null) return;
    await _carregarSlots(servico.id, colaborador.id);
  }

  // a tela já conferiu que cliente, serviço, profissional e hora existem
  Future<void> salvar({String observacoes = ''}) async {
    final cliente = _cliente;
    final servico = _servico;
    final hora = _hora;
    if (cliente == null || servico == null || hora == null) return;

    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    final result = await _criar(
      NovoAgendamentoParams(
        clienteId: cliente.id,
        servicoId: servico.id,
        colaboradorId: _colaborador?.id,
        dataHora: juntarDataHora(_data, hora),
        observacoes: observacoes,
      ),
    );
    if (_disposed) return;

    result.fold(
      (failure) {
        if (failure is ValidationFailure && failure.fields.isNotEmpty) {
          _fieldErrors = {
            for (final e in failure.fields.entries)
              if (e.value.isNotEmpty) e.key: e.value.first,
          };
        } else {
          _errorMessage = failure.message;
        }
        // alguém marcou ou bloqueou esse horário enquanto a tela estava
        // aberta: a grade precisa mostrar isso
        if (failure.code == 'horario_conflito' ||
            failure.code == 'horario_bloqueado') {
          _hora = null;
          recarregarGrade();
        }
      },
      (criado) {
        _criado = criado;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// com o que o formulário abre: o dia, a hora tocada na grade e o
// profissional filtrado (todos opcionais)
class NovoAgendamentoArgs extends Equatable {
  const NovoAgendamentoArgs({this.data, this.hora, this.colaboradorId});

  final DateTime? data;
  final Hora? hora;
  final int? colaboradorId;

  @override
  List<Object?> get props => [data, hora, colaboradorId];
}
