import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';

import '../../domain/entities/empresa_config.dart';
import '../../domain/entities/horario_funcionamento.dart';
import '../../domain/entities/nicho.dart';
import '../../domain/usecases/buscar_config_use_case.dart';
import '../../domain/usecases/buscar_endereco_por_cep_use_case.dart';
import '../../domain/usecases/buscar_horarios_use_case.dart';
import '../../domain/usecases/concluir_onboarding_use_case.dart';
import '../../domain/usecases/salvar_config_use_case.dart';
import '../../domain/usecases/salvar_horarios_use_case.dart';

// as etapas do wizard: a tela mostra uma de cada vez
enum WizardStep { negocio, nicho, horarios, concluido }

class WizardProvider extends ChangeNotifier {
  WizardProvider({
    required this._buscarConfig,
    required this._salvarConfig,
    required this._buscarEnderecoPorCep,
    required this._buscarHorarios,
    required this._salvarHorarios,
    required this._concluirOnboarding,
  });

  final BuscarConfigUseCase _buscarConfig;
  final SalvarConfigUseCase _salvarConfig;
  final BuscarEnderecoPorCepUseCase _buscarEnderecoPorCep;
  final BuscarHorariosUseCase _buscarHorarios;
  final SalvarHorariosUseCase _salvarHorarios;
  final ConcluirOnboardingUseCase _concluirOnboarding;

  // estado da tela (privado, só o provider altera)
  WizardStep _step = WizardStep.negocio;
  EmpresaConfig _config = const EmpresaConfig();
  List<HorarioFuncionamento> _horarios = [];
  bool _carregado = false;
  bool _isLoading = false;
  String? _errorMessage;

  // a busca de CEP tem loading e erro próprios: ela roda no meio do step 1
  // e não pode travar nem sujar o resto da tela
  bool _buscandoCep = false;
  String? _cepErrorMessage;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  // getters: a tela só consegue ler
  WizardStep get step => _step;
  EmpresaConfig get config => _config;
  List<HorarioFuncionamento> get horarios => List.unmodifiable(_horarios);
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get buscandoCep => _buscandoCep;
  String? get cepErrorMessage => _cepErrorMessage;

  // o step 1 só mostra o campo de número depois que o CEP achou o endereço
  bool get temEndereco => _config.endereco.isNotEmpty;

  // o step 3 pede capacidade diária só para agenda kanban
  bool get isKanban => _config.tipoAgenda == TipoAgenda.kanban;

  // abre o wizard: carrega o que já foi salvo e continua de onde parou
  Future<void> carregar() async {
    await _run(() => _buscarConfig(NoParams()), (config) {
      _config = config;
    });
    if (_errorMessage != null) return;

    await _run(() => _buscarHorarios(NoParams()), (horarios) {
      _horarios = horarios;
      _carregado = true;
      _step = _primeiraEtapaIncompleta();
    });
  }

  // step 1: chamado quando o usuário termina de digitar o CEP
  Future<void> buscarCep(String cep) async {
    _buscandoCep = true;
    _cepErrorMessage = null;
    notifyListeners();

    final result = await _buscarEnderecoPorCep(cep);
    if (_disposed) return;

    result.fold(
      (failure) {
        _cepErrorMessage = failure.message;
        // o endereço antigo não vale para o CEP novo
        _config = _config.copyWith(endereco: '', cidade: '', uf: '');
      },
      (endereco) {
        _config = _config.copyWith(
          cep: endereco.cep,
          endereco: endereco.endereco,
          cidade: endereco.cidade,
          uf: endereco.uf,
        );
      },
    );

    _buscandoCep = false;
    notifyListeners();
  }

  // step 1 -> step 2. o CEP, o endereço, a cidade e a UF já estão na config
  Future<void> salvarNegocio({
    required String nome,
    required String telefone,
    required TipoDocumento tipoDocumento,
    required String documento,
    required String numero,
  }) async {
    final config = _config.copyWith(
      nome: nome.trim(),
      telefone: _soDigitos(telefone),
      tipoDocumento: tipoDocumento,
      documento: _soDigitos(documento),
      numero: numero.trim(),
    );
    await _run(() => _salvarConfig(config), (salva) {
      _config = salva;
      _step = WizardStep.nicho;
    });
  }

  // step 2: marcar um card só muda a tela; salvar é no "Próximo"
  void escolherNicho(Nicho nicho) {
    _config = _config.copyWith(nicho: nicho);
    notifyListeners();
  }

  // step 2, nicho outro: a resposta de "como você atende?" define o modo.
  // no horário não há objeto, e o backend descarta o que tiver sobrado
  void escolherModo(TipoAgenda tipoAgenda, {TipoObjeto? tipoObjeto}) {
    _config = _config.copyWith(tipoAgenda: tipoAgenda, tipoObjeto: tipoObjeto);
    notifyListeners();
  }

  // step 2 -> step 3. a resposta traz o tipo de agenda, que decide se o
  // step 3 mostra a capacidade. a descrição só vale no nicho outro
  Future<void> salvarNicho({String descricao = ''}) async {
    final nicho = _config.nicho;
    if (nicho == null) {
      _errorMessage = 'Escolha o ramo do seu negócio';
      notifyListeners();
      return;
    }
    // o card do kanban é sempre um veículo ou um pet
    if (nicho == Nicho.outro && isKanban && _config.tipoObjeto == null) {
      _errorMessage = 'Diga se você recebe veículos ou pets';
      notifyListeners();
      return;
    }

    final config = _config.copyWith(
      nichoDescricao: nicho == Nicho.outro ? descricao.trim() : '',
    );
    await _run(() => _salvarConfig(config), (salva) {
      _config = salva;
      _step = WizardStep.horarios;
    });
  }

  // step 3: cada mudança num dia troca o horário daquele dia na lista
  void atualizarHorario(HorarioFuncionamento horario) {
    _horarios = [for (final h in _horarios) h.dia == horario.dia ? horario : h];
    notifyListeners();
  }

  // a tela mostra a mensagem embaixo do dia; null quando está tudo certo
  String? erroDoHorario(HorarioFuncionamento horario) {
    if (!horario.ativo) return null;

    final abertura = horario.abertura;
    final fechamento = horario.fechamento;
    if (abertura == null || fechamento == null) {
      return 'Informe a abertura e o fechamento';
    }
    if (fechamento.emMinutos <= abertura.emMinutos) {
      return 'O fechamento precisa ser depois da abertura';
    }
    if (isKanban && (horario.capacidade ?? 0) < 1) {
      return 'Informe quantos atendimentos cabem no dia';
    }
    return null;
  }

  // step 3 -> fim: salva os horários e conclui o onboarding
  Future<void> concluir() async {
    if (!_horarios.any((h) => h.ativo)) {
      _errorMessage = 'Abra pelo menos um dia da semana';
      notifyListeners();
      return;
    }
    if (_horarios.any((h) => erroDoHorario(h) != null)) {
      _errorMessage = 'Corrija os horários marcados';
      notifyListeners();
      return;
    }

    await _run(() => _salvarHorarios(_horarios), (salvos) {
      _horarios = salvos;
    });
    if (_errorMessage != null) return;

    await _run(() => _concluirOnboarding(NoParams()), (config) {
      _config = config;
      _step = WizardStep.concluido;
    });
  }

  // botão "Voltar": nada é perdido, a config continua no provider
  void voltar() {
    _step = switch (_step) {
      WizardStep.nicho => WizardStep.negocio,
      WizardStep.horarios => WizardStep.nicho,
      _ => _step,
    };
    _errorMessage = null; // o erro era da etapa que ficou para trás
    notifyListeners();
  }

  WizardStep _primeiraEtapaIncompleta() {
    if (_config.onboardingConcluido) return WizardStep.concluido;
    if (_config.documento.isEmpty || _config.cep.isEmpty) {
      return WizardStep.negocio;
    }
    if (_config.nicho == null) return WizardStep.nicho;
    return WizardStep.horarios;
  }

  // molde de toda ação: liga o loading, chama o use case e guarda o erro.
  // erro de validação da API vira a mensagem do campo que falhou (documento,
  // CEP...), que diz mais que o "Dados inválidos." genérico
  Future<void> _run<T>(
    Future<Either<Failure, T>> Function() acao,
    void Function(T valor) sucesso,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // avisa a tela: "estou carregando"

    final result = await acao();
    if (_disposed) return;

    result.fold((failure) {
      _errorMessage = failure is ValidationFailure
          ? failure.resumo
          : failure.message;
    }, sucesso);

    _isLoading = false;
    notifyListeners(); // avisa a tela: "terminei" (e a etapa nova, se mudou)
  }

  // máscaras ficam na tela; o backend guarda só os dígitos
  String _soDigitos(String valor) => valor.replaceAll(RegExp(r'\D'), '');

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
