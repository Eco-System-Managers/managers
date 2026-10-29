import 'package:flutter_test/flutter_test.dart';
import 'package:managers/features/empresa/domain/entities/nicho.dart';

void main() {
  group('aceita', () {
    test('a primeira escolha aceita qualquer nicho', () {
      expect(<Nicho>[].aceita(Nicho.lavaRapido), isTrue);
    });

    test('só aceita nicho da mesma área', () {
      final escolhidos = [Nicho.barbearia];

      expect(escolhidos.aceita(Nicho.massagem), isTrue);
      expect(escolhidos.aceita(Nicho.lavaRapido), isFalse);
    });

    test('veículo e pet são áreas diferentes', () {
      expect([Nicho.lavaRapido].aceita(Nicho.banhoTosa), isFalse);
    });

    test('no limite de 4, só os marcados podem sair', () {
      final escolhidos = [
        Nicho.cabeleireiro,
        Nicho.barbearia,
        Nicho.manicure,
        Nicho.pedicure,
      ];

      expect(escolhidos.aceita(Nicho.massagem), isFalse);
      expect(escolhidos.aceita(Nicho.manicure), isTrue);
    });
  });

  group('alternar', () {
    test('marca na ordem de exibição', () {
      expect([Nicho.massagem].alternar(Nicho.cabeleireiro), [
        Nicho.cabeleireiro,
        Nicho.massagem,
      ]);
    });

    test('desmarca o que já estava marcado', () {
      expect([Nicho.manicure, Nicho.massagem].alternar(Nicho.manicure), [
        Nicho.massagem,
      ]);
    });

    test('o que a regra recusa deixa a escolha como está', () {
      expect([Nicho.barbearia].alternar(Nicho.lavaRapido), [Nicho.barbearia]);
    });

    test('o outro vai sempre sozinho', () {
      expect([Nicho.barbearia].alternar(Nicho.outro), [Nicho.outro]);
      expect([Nicho.outro].alternar(Nicho.barbearia), [Nicho.barbearia]);
    });
  });

  test('doSlug acha pelo valor do backend', () {
    expect(Nicho.doSlug('design_sobrancelhas'), Nicho.designSobrancelhas);
    expect(Nicho.doSlug('padaria'), isNull);
  });
}
