import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:managers/core/error/failures.dart';

import '../../domain/entities/objeto_cliente.dart';
import '../../domain/usecases/objetos_use_cases.dart';

// estado do formulário de veículo ou pet (montado em clientes_provider.dart,
// na raiz da feature): salvar e remover; a ficha recarrega depois
class ObjetoFormProvider extends ChangeNotifier {
  ObjetoFormProvider({
    required this._salvarVeiculo,
    required this._removerVeiculo,
    required this._salvarPet,
    required this._removerPet,
  });

  final SalvarVeiculoUseCase _salvarVeiculo;
  final RemoverVeiculoUseCase _removerVeiculo;
  final SalvarPetUseCase _salvarPet;
  final RemoverPetUseCase _removerPet;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  bool _salvo = false;
  bool _removido = false;

  // a folha pode ser fechada durante uma requisição
  bool _disposed = false;

  bool get isLoading => _isLoading;

  // erro que não é de campo
  String? get errorMessage => _errorMessage;

  // erro de validação da API, campo a campo, com os nomes do contrato
  // (placa, marca, modelo, cor, nome, especie, raca, porte, data_nascimento)
  String? erroDoCampo(String campo) => _fieldErrors[campo];

  // true depois de salvar ou remover: a folha fecha
  bool get salvo => _salvo;
  bool get removido => _removido;

  Future<void> salvarVeiculo(Veiculo veiculo) =>
      _executar(() => _salvarVeiculo(veiculo), aoSalvar: true);

  Future<void> salvarPet(Pet pet) =>
      _executar(() => _salvarPet(pet), aoSalvar: true);

  Future<void> removerVeiculo(int id) =>
      _executar(() => _removerVeiculo(id), aoSalvar: false);

  Future<void> removerPet(int id) =>
      _executar(() => _removerPet(id), aoSalvar: false);

  Future<void> _executar<T>(
    Future<Either<Failure, T>> Function() acao, {
    required bool aoSalvar,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = const {};
    notifyListeners();

    final result = await acao();
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
      (_) {
        if (aoSalvar) {
          _salvo = true;
        } else {
          _removido = true;
        }
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  void limparErroDoCampo(String campo) {
    if (!_fieldErrors.containsKey(campo)) return;
    _fieldErrors = {..._fieldErrors}..remove(campo);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
