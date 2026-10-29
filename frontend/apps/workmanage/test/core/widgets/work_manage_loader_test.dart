import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/widgets/work_manage_loader.dart';

// avança o relógio em quadros de 16 ms, como na tela
Future<void> _avancar(WidgetTester tester, Duration tempo) async {
  const quadro = Duration(milliseconds: 16);
  var passou = Duration.zero;
  while (passou < tempo) {
    await tester.pump(quadro);
    passou += quadro;
  }
}

// como na splash: começa com o símbolo completo, fica 1,2 s e sai em 0,8 s.
// o primeiro ciclo dura 2 s; os seguintes, com a entrada, quase 5 s
Widget _splash({required bool loop, required VoidCallback onCycleEnd}) {
  return MaterialApp(
    home: Center(
      child: WorkManageLoader(
        startFull: true,
        loop: loop,
        pauseDuration: const Duration(milliseconds: 1200),
        onCycleEnd: onCycleEnd,
      ),
    ),
  );
}

void main() {
  testWidgets('com loop, avisa o fim de cada ciclo e recomeça', (tester) async {
    var ciclos = 0;
    await tester.pumpWidget(_splash(loop: true, onCycleEnd: () => ciclos++));

    await _avancar(tester, const Duration(milliseconds: 1900));
    expect(ciclos, 0);
    await _avancar(tester, const Duration(milliseconds: 200));
    expect(ciclos, 1);

    // o ciclo inteiro, com a entrada, passa de 4,5 s e fica abaixo de 5,1 s
    await _avancar(tester, const Duration(milliseconds: 4500));
    expect(ciclos, 1);
    await _avancar(tester, const Duration(milliseconds: 600));
    expect(ciclos, 2);
  });

  testWidgets('desligar o loop no meio do ciclo deixa esse ciclo terminar', (
    tester,
  ) async {
    var ciclos = 0;
    void contar() => ciclos++;
    await tester.pumpWidget(_splash(loop: true, onCycleEnd: contar));
    await _avancar(tester, const Duration(milliseconds: 2100));
    expect(ciclos, 1);

    // a rota é decidida com o símbolo ainda entrando, no segundo ciclo
    await _avancar(tester, const Duration(milliseconds: 1000));
    await tester.pumpWidget(_splash(loop: false, onCycleEnd: contar));

    // o ciclo não é cortado: ainda não acabou
    await _avancar(tester, const Duration(milliseconds: 3400));
    expect(ciclos, 1);

    // acaba uma vez e não recomeça
    await _avancar(tester, const Duration(milliseconds: 800));
    expect(ciclos, 2);
    await _avancar(tester, const Duration(seconds: 6));
    expect(ciclos, 2);
  });

  testWidgets('o fim de ciclo que desliga o loop não deixa o símbolo voltar', (
    tester,
  ) async {
    // na splash, a rota decidida no mesmo quadro em que o ciclo acaba: quem
    // usa desliga o loop dentro do próprio aviso de fim de ciclo
    final loop = ValueNotifier(true);
    addTearDown(loop.dispose);
    var ciclos = 0;
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: loop,
        builder: (context, valor, _) => _splash(
          loop: valor,
          onCycleEnd: () {
            ciclos++;
            loop.value = false;
          },
        ),
      ),
    );

    await _avancar(tester, const Duration(milliseconds: 2100));
    expect(ciclos, 1);
    await _avancar(tester, const Duration(seconds: 6));
    expect(ciclos, 1);
  });
}
