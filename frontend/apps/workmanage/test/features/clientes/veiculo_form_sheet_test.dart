import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/theme/theme.dart';
import 'package:managers/features/clientes/clientes_provider.dart';
import 'package:managers/features/clientes/domain/entities/objeto_cliente.dart';
import 'package:managers/features/clientes/domain/usecases/objetos_use_cases.dart';
import 'package:managers/features/clientes/presentation/widgets/veiculo_form_sheet.dart';
import 'package:mocktail/mocktail.dart';

class _MockSalvarVeiculo extends Mock implements SalvarVeiculoUseCase {}

const _uno = Veiculo(
  id: 3,
  clienteId: 7,
  placa: 'ABC1D23',
  marca: 'Fiat',
  modelo: 'Uno',
  cor: 'Prata',
  porte: Porte.carro,
);

void main() {
  setUpAll(() => registerFallbackValue(_uno));

  // a folha fechava uma vez por redesenho depois de salvar: o teclado
  // fechando durante a saída fechava também a tela de baixo
  testWidgets('salvar fecha só a folha, mesmo com o teclado fechando', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final salvar = _MockSalvarVeiculo();
    when(() => salvar(any())).thenAnswer((_) async => const Right(_uno));
    bool? resultado;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [salvarVeiculoUseCaseProvider.overrideWithValue(salvar)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      body: Column(
                        children: [
                          const Text('Receber veículo'),
                          FilledButton(
                            onPressed: () async => resultado =
                                await VeiculoFormSheet.abrir(
                                  context,
                                  clienteId: 7,
                                  veiculo: _uno,
                                ),
                            child: const Text('Editar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    // teclado aberto
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pump();
    // o teclado fecha enquanto a folha sai
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();

    expect(find.byType(VeiculoFormSheet), findsNothing);
    expect(find.text('Receber veículo'), findsOneWidget);
    expect(resultado, isTrue);
    verify(() => salvar(any())).called(1);
  });
}
