import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/core/usecases/use_case.dart';
import 'package:managers/features/empresa/domain/entities/nicho.dart';
import 'package:managers/features/empresa/presentation/providers/negocio_atual_provider.dart';
import 'package:managers/features/usuarios/domain/entities/colaborador.dart';
import 'package:managers/features/usuarios/domain/usecases/listar_colaboradores_use_case.dart';

import '../../domain/entities/servico.dart';
import '../../domain/params/alterar_ativo_params.dart';
import '../../domain/usecases/alterar_ativo_servico_use_case.dart';
import '../../domain/usecases/atualizar_servico_use_case.dart';
import '../../domain/usecases/criar_servico_use_case.dart';
import '../../domain/usecases/obter_servico_use_case.dart';

// estado do formulário de serviço (montado em servicos_provider.dart, na
// raiz da feature): novo quando o id é null, edição quando não é. carrega
// a equipe para a escolha de quem executa. os nichos do negócio são as
// pastas em que o serviço pode ficar
class ServicoFormProvider extends ChangeNotifier {
  ServicoFormProvider({
    required this.id,
    required this._obter,
    required this._criar,
    required this._atualizar,
    required this._alterarAtivo,
    required this._listarColaboradores,
    required this._negocio,
  });

  // null = serviço novo
  final int? id;

  final ObterServicoUseCase _obter;
  final CriarServicoUseCase _criar;
  final AtualizarServicoUseCase _atualizar;
  final AlterarAtivoServicoUseCase _alterarAtivo;
  final ListarColaboradoresUseCase _listarColaboradores;
  final NegocioAtualProvider _negocio;

  Servico? _servico;
  List<Colaborador> _colaboradores = [];
  bool _carregado = false;
  bool _isLoading = false;
  Failure? _erroAoCarregar;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  bool _salvo = false;

  // a tela pode ser fechada durante uma requisição
  bool _disposed = false;

  bool get ehNovo => id == null;

  List<Nicho> get nichos => _negocio.config?.nichos ?? const [];

  // com um nicho só não há o que escolher: o serviço fica nele
  bool get escolheNicho => nichos.length > 1;

  // null enquanto carrega ou quando é novo
  Servico? get servico => _servico;
  List<Colaborador> get colaboradores => List.unmodifiable(_colaboradores);
  bool get carregado => _carregado;
  bool get isLoading => _isLoading;
  Failure? get erroAoCarregar => _erroAoCarregar;

  // erro que não é de campo (rede, permissão, regra sem campo)
  String? get errorMessage => _errorMessage;

  // erro de validação da API, campo a campo: a tela mostra embaixo do
  // campo certo (nome, duracao, preco, taxa_cancelamento_valor...)
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  // true depois de salvar ou inativar: a tela fecha
  bool get salvo => _salvo;

  Future<void> carregar() async {
    _isLoading = true;
    _erroAoCarregar = null;
    notifyListeners();

    final equipe = await _listarColaboradores(NoParams());
    if (_disposed) return;
    equipe.fold(
      (failure) => _erroAoCarregar = failure,
      (lista) => _colaboradores = lista,
    );

    final id = this.id;
    if (_erroAoCarregar == null && id != null) {
      final result = await _obter(id);
      if (_disposed) return;
      result.fold((failure) => _erroAoCarregar = failure, (s) => _servico = s);
    }

    _carregado = _erroAoCarregar == null;
    _isLoading = false;
    notifyListeners();
  }

  // a tela entrega o serviço montado a partir dos campos, já validados
  Future<void> salvar(Servico dados) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    final id = this.id;
    final result = id == null
        ? await _criar(dados)
        : await _atualizar(dados.copyWith(id: id));
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
      },
      (salvo) {
        _servico = salvo;
        _salvo = true;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  // a pessoa mexeu no campo: o erro que a API apontou nele não vale mais
  void limparErroDoCampo(String campo) {
    if (!_fieldErrors.containsKey(campo)) return;
    _fieldErrors = {..._fieldErrors}..remove(campo);
    notifyListeners();
  }

  // inativar ou reativar o serviço aberto; a tela fecha e a lista recarrega
  Future<void> alterarAtivo(bool ativo) async {
    final id = this.id;
    if (id == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _alterarAtivo(
      AlterarAtivoParams(id: id, ativo: ativo),
    );
    if (_disposed) return;

    result.fold((failure) => _errorMessage = failure.message, (salvo) {
      _servico = salvo;
      _salvo = true;
    });

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
