import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/theme/theme.dart';
import 'package:managers/features/empresa/domain/entities/nicho.dart';
import 'package:managers/features/servicos/domain/entities/servico.dart';
import 'package:managers/features/servicos/presentation/widgets/itens_de_servico.dart';

Servico _servico(int id, String nome, Nicho nicho) => Servico(
  id: id,
  nome: nome,
  nicho: nicho,
  duracao: 30,
  preco: Decimal.parse('50'),
);

// monta os itens dentro de um MaterialApp com o tema, que é de onde saem as
// cores do título do nicho
Future<List<DropdownMenuItem<Servico>>> _itens(
  WidgetTester tester,
  List<Servico> servicos,
) async {
  late List<DropdownMenuItem<Servico>> itens;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) {
          itens = itensDeServico(
            context,
            servicos: servicos,
            rotulo: (s) => s.nome,
          );
          return const SizedBox();
        },
      ),
    ),
  );
  return itens;
}

void main() {
  testWidgets('com um nicho só, a lista fica corrida', (tester) async {
    final itens = await _itens(tester, [
      _servico(1, 'Corte', Nicho.barbearia),
      _servico(2, 'Barba', Nicho.barbearia),
    ]);

    expect(itens.map((i) => i.value?.nome), ['Corte', 'Barba']);
    expect(itens.every((i) => i.enabled), isTrue);
  });

  testWidgets('com mais de um, um título por nicho na ordem de exibição', (
    tester,
  ) async {
    final itens = await _itens(tester, [
      _servico(1, 'Relaxante', Nicho.massagem),
      _servico(2, 'Corte', Nicho.barbearia),
      _servico(3, 'Barba', Nicho.barbearia),
    ]);

    // os títulos não têm valor e não podem ser escolhidos
    expect(itens.map((i) => i.value?.nome), [
      null,
      'Corte',
      'Barba',
      null,
      'Relaxante',
    ]);
    expect(itens.where((i) => !i.enabled), hasLength(2));
  });
}
