import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/error/failures.dart';
import 'package:managers/features/clientes/domain/entities/objeto_cliente.dart';
import 'package:managers/features/clientes/domain/usecases/objetos_use_cases.dart';
import 'package:managers/features/clientes/presentation/providers/objeto_form_provider.dart';
import 'package:mocktail/mocktail.dart';

class _MockSalvarVeiculo extends Mock implements SalvarVeiculoUseCase {}

class _MockRemoverVeiculo extends Mock implements RemoverVeiculoUseCase {}

class _MockSalvarPet extends Mock implements SalvarPetUseCase {}

class _MockRemoverPet extends Mock implements RemoverPetUseCase {}

const _uno = Veiculo(
  clienteId: 7,
  placa: 'ABC1D23',
  marca: 'Fiat',
  modelo: 'Uno',
  cor: 'Prata',
);

void main() {
  late _MockSalvarVeiculo salvarVeiculo;
  late _MockRemoverVeiculo removerVeiculo;
  late _MockSalvarPet salvarPet;
  late _MockRemoverPet removerPet;

  setUpAll(() {
    registerFallbackValue(_uno);
    registerFallbackValue(const Pet(clienteId: 7, nome: 'Rex'));
  });

  ObjetoFormProvider montar() => ObjetoFormProvider(
    salvarVeiculo: salvarVeiculo,
    removerVeiculo: removerVeiculo,
    salvarPet: salvarPet,
    removerPet: removerPet,
  );

  setUp(() {
    salvarVeiculo = _MockSalvarVeiculo();
    removerVeiculo = _MockRemoverVeiculo();
    salvarPet = _MockSalvarPet();
    removerPet = _MockRemoverPet();
  });

  test(
    'salvar veículo fecha a folha; erro de validação vai para o campo',
    () async {
      when(() => salvarVeiculo(any())).thenAnswer(
        (invocation) async =>
            Right((invocation.positionalArguments.single as Veiculo)),
      );
      final provider = montar();

      await provider.salvarVeiculo(_uno);
      expect(provider.salvo, isTrue);

      when(() => salvarVeiculo(any())).thenAnswer(
        (_) async => const Left(
          ValidationFailure(
            fields: {
              'placa': ['Placa inválida.'],
            },
          ),
        ),
      );
      final outro = montar();
      await outro.salvarVeiculo(_uno);

      expect(outro.salvo, isFalse);
      expect(outro.erroDoCampo('placa'), 'Placa inválida.');
      outro.limparErroDoCampo('placa');
      expect(outro.erroDoCampo('placa'), isNull);
    },
  );

  test('remover pet fecha a folha; erro vira mensagem', () async {
    when(() => removerPet(5)).thenAnswer((_) async => const Right(null));
    final provider = montar();

    await provider.removerPet(5);
    expect(provider.removido, isTrue);

    when(() => removerPet(6))
        .thenAnswer((_) async => const Left(ServerFailure(message: 'Falhou.')));
    final outro = montar();
    await outro.removerPet(6);

    expect(outro.removido, isFalse);
    expect(outro.errorMessage, 'Falhou.');
  });

  test('salvar pet manda a entidade como veio', () async {
    const rex = Pet(
      clienteId: 7,
      nome: 'Rex',
      especie: 'Cachorro',
      porte: PortePet.medio,
    );
    when(() => salvarPet(any())).thenAnswer((_) async => const Right(rex));
    final provider = montar();

    await provider.salvarPet(rex);

    expect(verify(() => salvarPet(captureAny())).captured.single, rex);
    expect(provider.salvo, isTrue);
  });
}
