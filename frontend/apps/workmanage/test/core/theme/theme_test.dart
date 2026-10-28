import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managers/core/theme/brand.dart';
import 'package:managers/core/theme/theme.dart';

// o tema não inventa valor: as cores do código são as de tokens.json e todo
// par de texto sobre fundo passa de 4.5:1 nos dois temas
void main() {
  double contraste(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (la > lb ? la + 0.05 : lb + 0.05) /
        (la > lb ? lb + 0.05 : la + 0.05);
  }

  Color hex(String valor) =>
      Color(0xFF000000 | int.parse(valor.substring(1), radix: 16));

  group('tokens.json', () {
    final tokens = jsonDecode(
      File('../../../design/tokens/tokens.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final cores = {
      for (final t in (tokens['color'] as Map)['tokens'] as List)
        t['name'] as String: t['value'] as Map,
    };

    Map<String, Color> doTema(BrandColors c) => {
      'navy': c.navy,
      'blue': c.blue,
      'blue-soft': c.blueSoft,
      'bg': c.bg,
      'bg-2': c.bg2,
      'border': c.border,
      'ink': c.ink,
      'ink-muted': c.inkMuted,
      'on-brand': c.onBrand,
      'success': c.success,
      'warning': c.warning,
      'danger': c.danger,
    };

    test('as cores de cada tema são as do arquivo', () {
      for (final (tema, c) in [
        ('light', BrandColors.light),
        ('dark', BrandColors.dark),
      ]) {
        final noCodigo = doTema(c);
        expect(noCodigo.keys.toSet(), cores.keys.toSet());
        for (final nome in cores.keys) {
          expect(
            noCodigo[nome],
            hex(cores[nome]![tema] as String),
            reason: '$nome no tema $tema',
          );
        }
      }
    });

    test('espaçamento e raio são os do arquivo', () {
      double px(String v) => double.parse(v.replaceAll('px', ''));
      final espacos = {
        for (final t in (tokens['spacing'] as Map)['tokens'] as List)
          t['name'] as String: px(t['value'] as String),
      };
      expect(espacos, {
        'space-1': BrandSpacing.space1,
        'space-2': BrandSpacing.space2,
        'space-3': BrandSpacing.space3,
        'space-4': BrandSpacing.space4,
        'space-5': BrandSpacing.space5,
        'space-6': BrandSpacing.space6,
        'space-7': BrandSpacing.space7,
      });
      final raios = {
        for (final t in (tokens['radius'] as Map)['tokens'] as List)
          t['name'] as String: t['value'] as String,
      };
      expect(px(raios['radius-sm']!), BrandRadius.sm);
      expect(px(raios['radius-md']!), BrandRadius.md);
      expect(px(raios['radius-lg']!), BrandRadius.lg);
      expect(raios['radius-icon'], '${(BrandRadius.icon * 100).round()}%');
    });
  });

  group('ColorScheme', () {
    test('claro: os papéis pedidos são exatamente os tokens', () {
      final s = AppTheme.light().colorScheme;
      expect(s.primary, const Color(0xFF1B6AF3));
      expect(s.onPrimary, const Color(0xFFFFFFFF));
      expect(s.secondary, const Color(0xFF0B1C35));
      expect(s.onSurface, const Color(0xFF0B1C35));
      expect(s.surface, const Color(0xFFFFFFFF));
      expect(s.surfaceContainer, const Color(0xFFF3F6FD));
      expect(s.outline, const Color(0xFFDFE6F1));
      expect(s.error, const Color(0xFFB3261E));
    });

    test('escuro: os papéis pedidos são exatamente os tokens', () {
      final s = AppTheme.dark().colorScheme;
      expect(s.primary, const Color(0xFF5A93FF));
      expect(s.surface, const Color(0xFF0B1C35));
      expect(s.surfaceContainer, const Color(0xFF13254A));
      expect(s.outline, const Color(0xFF2A3B5C));
      expect(s.error, const Color(0xFFFF7B72));
    });
  });

  group('contraste 4.5:1', () {
    for (final (nome, tema) in [
      ('claro', AppTheme.light()),
      ('escuro', AppTheme.dark()),
    ]) {
      test('tema $nome', () {
        final s = tema.colorScheme;
        final c = tema.extension<BrandColors>()!;
        final pares = <String, (Color, Color)>{
          'ink/bg': (c.ink, c.bg),
          'ink/bg2': (c.ink, c.bg2),
          'inkMuted/bg': (c.inkMuted, c.bg),
          'inkMuted/bg2': (c.inkMuted, c.bg2),
          'blue/bg (link)': (c.blue, c.bg),
          'branco/azul da marca (botão)': (c.onBrand, BrandColors.brandBlue),
          'onPrimary/primary': (s.onPrimary, s.primary),
          'onError/error': (s.onError, s.error),
          'onErrorContainer/errorContainer': (
            s.onErrorContainer,
            s.errorContainer,
          ),
          'onSecondaryContainer/secondaryContainer': (
            s.onSecondaryContainer,
            s.secondaryContainer,
          ),
          'onPrimaryContainer/primaryContainer': (
            s.onPrimaryContainer,
            s.primaryContainer,
          ),
          'onInverseSurface/inverseSurface': (
            s.onInverseSurface,
            s.inverseSurface,
          ),
          'danger/bg': (c.danger, c.bg),
          'success/bg': (c.success, c.bg),
          'warning/bg': (c.warning, c.bg),
          'aviso: texto': (
            tema.snackBarTheme.contentTextStyle!.color!,
            tema.snackBarTheme.backgroundColor!,
          ),
          'aviso: ação': (
            tema.snackBarTheme.actionTextColor!,
            tema.snackBarTheme.backgroundColor!,
          ),
        };
        for (final MapEntry(key: par, value: (texto, fundo)) in pares.entries) {
          expect(
            contraste(texto, fundo),
            greaterThanOrEqualTo(4.5),
            reason: '$par no tema $nome',
          );
        }
      });
    }
  });

  group('tipografia', () {
    test('a interface inteira é Inter, nos tamanhos do Design System', () {
      final tamanhos = <double>{56, 40, 32, 24, 18, 15, 13, 12};
      final t = AppTheme.light().textTheme;
      final papeis = {
        'displayLarge': (t.displayLarge, FontWeight.w700),
        'displayMedium': (t.displayMedium, FontWeight.w700),
        'displaySmall': (t.displaySmall, FontWeight.w700),
        'headlineLarge': (t.headlineLarge, FontWeight.w700),
        'headlineMedium': (t.headlineMedium, FontWeight.w700),
        'headlineSmall': (t.headlineSmall, FontWeight.w700),
        'titleLarge': (t.titleLarge, FontWeight.w600),
        'titleMedium': (t.titleMedium, FontWeight.w600),
        'titleSmall': (t.titleSmall, FontWeight.w600),
        'bodyLarge': (t.bodyLarge, FontWeight.w400),
        'bodyMedium': (t.bodyMedium, FontWeight.w400),
        'bodySmall': (t.bodySmall, FontWeight.w400),
        'labelLarge': (t.labelLarge, FontWeight.w500),
        'labelMedium': (t.labelMedium, FontWeight.w500),
        'labelSmall': (t.labelSmall, FontWeight.w500),
      };
      for (final MapEntry(key: papel, value: (estilo, peso))
          in papeis.entries) {
        expect(estilo!.fontFamily, BrandText.sans, reason: papel);
        expect(tamanhos, contains(estilo.fontSize), reason: papel);
        expect(estilo.fontWeight, peso, reason: papel);
      }
    });

    test('MuseoModerno só nos estilos de marca', () {
      expect(BrandText.wordmark.fontFamily, BrandText.brand);
      expect(BrandText.display.fontFamily, BrandText.brand);
      for (final estilo in [
        BrandText.h1,
        BrandText.h2,
        BrandText.h3,
        BrandText.body,
        BrandText.bodyStrong,
        BrandText.label,
        BrandText.caption,
      ]) {
        expect(estilo.fontFamily, BrandText.sans);
      }
    });
  });

  testWidgets('o detalhe da linha de lista sai em inkMuted, o nome em ink', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: ListTile(title: Text('Ana Silva'), subtitle: Text('Cliente')),
        ),
      ),
    );
    Color? corDe(String texto) => tester
        .widget<AnimatedDefaultTextStyle>(
          find
              .ancestor(
                of: find.text(texto),
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first,
        )
        .style
        .color;
    expect(corDe('Ana Silva'), BrandColors.light.ink);
    expect(corDe('Cliente'), BrandColors.light.inkMuted);
  });

  // monta os componentes com tema nos dois modos: pega erro de tema que só
  // aparece na hora de desenhar
  for (final (nome, tema) in [
    ('claro', AppTheme.light()),
    ('escuro', AppTheme.dark()),
  ]) {
    testWidgets('componentes desenham no tema $nome', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: tema,
          home: Scaffold(
            appBar: AppBar(title: const Text('Clientes')),
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add_rounded),
            ),
            body: ListView(
              children: [
                FilledButton(onPressed: () {}, child: const Text('Salvar')),
                OutlinedButton(onPressed: () {}, child: const Text('Voltar')),
                TextButton(onPressed: () {}, child: const Text('Ver todos')),
                const TextField(decoration: InputDecoration(labelText: 'Nome')),
                FilterChip(
                  label: const Text('Hoje'),
                  selected: true,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('7 dias'),
                  selected: false,
                  onSelected: (_) {},
                ),
                Switch(value: true, onChanged: (_) {}),
                Switch(value: false, onChanged: (_) {}),
                Checkbox(value: true, onChanged: (_) {}),
                const Card(child: ListTile(title: Text('Ana Silva'))),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Dia')),
                    ButtonSegment(value: 1, label: Text('Mês')),
                  ],
                  selected: const {0},
                  onSelectionChanged: (_) {},
                ),
                const LinearProgressIndicator(value: 0.5),
                const Divider(),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
