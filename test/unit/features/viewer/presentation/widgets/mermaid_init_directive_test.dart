import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/mermaid_block.dart';

void main() {
  group('buildMermaidInitDirective', () {
    final lightScheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    );

    String stripWrapper(String directive) {
      // Strips the `%%{init: ` prefix and `}%%\n` suffix to leave a
      // bare JSON object that `jsonDecode` can chew on.
      final trimmed = directive.trim();
      expect(trimmed, startsWith('%%{init: '));
      expect(trimmed, endsWith('}%%'));
      return trimmed.substring(
        '%%{init: '.length,
        trimmed.length - '}%%'.length,
      );
    }

    test('wraps the payload in the mermaid init directive sigil and ends with '
        'a newline so the actual diagram source starts on a fresh line', () {
      final directive = buildMermaidInitDirective(
        lightScheme,
        Brightness.light,
      );

      expect(directive, startsWith('%%{init: '));
      expect(directive, endsWith('%%\n'));
    });

    test('pins theme to "base" so themeVariables overrides take effect', () {
      final directive = buildMermaidInitDirective(
        lightScheme,
        Brightness.light,
      );
      final payload =
          jsonDecode(stripWrapper(directive)) as Map<String, dynamic>;

      expect(payload['theme'], 'base');
      expect(payload['themeVariables'], isA<Map<String, dynamic>>());
    });

    test('every variable value is a #RRGGBB hex string', () {
      final directive = buildMermaidInitDirective(
        lightScheme,
        Brightness.light,
      );
      final payload =
          jsonDecode(stripWrapper(directive)) as Map<String, dynamic>;
      final vars = payload['themeVariables'] as Map<String, dynamic>;

      final hexPattern = RegExp(r'^#[0-9a-fA-F]{6}$');
      for (final entry in vars.entries) {
        expect(
          entry.value,
          matches(hexPattern),
          reason:
              '${entry.key} must be a 6-digit hex colour (mermaid '
              'rejects named colours and transparent hex).',
        );
      }
    });

    test('covers every diagram type the viewer fixture exercises (flowchart, '
        'sequence, class, state, gantt, ER)', () {
      final directive = buildMermaidInitDirective(
        lightScheme,
        Brightness.light,
      );
      final payload =
          jsonDecode(stripWrapper(directive)) as Map<String, dynamic>;
      final vars = payload['themeVariables'] as Map<String, dynamic>;

      // Core
      expect(vars, containsPair('background', isA<String>()));
      expect(vars, containsPair('primaryColor', isA<String>()));
      expect(vars, containsPair('lineColor', isA<String>()));
      // Flowchart
      expect(vars, containsPair('nodeBkg', isA<String>()));
      expect(vars, containsPair('clusterBkg', isA<String>()));
      // Sequence
      expect(vars, containsPair('actorBkg', isA<String>()));
      expect(vars, containsPair('signalColor', isA<String>()));
      // State
      expect(vars, containsPair('compositeBackground', isA<String>()));
      // Gantt
      expect(vars, containsPair('taskBkgColor', isA<String>()));
      expect(vars, containsPair('todayLineColor', isA<String>()));
      // ER
      expect(vars, containsPair('relationColor', isA<String>()));
    });

    test('produces a different palette for light vs dark schemes built from '
        'the same seed', () {
      final lightDirective = buildMermaidInitDirective(
        lightScheme,
        Brightness.light,
      );
      final darkDirective = buildMermaidInitDirective(
        darkScheme,
        Brightness.dark,
      );

      expect(
        lightDirective,
        isNot(equals(darkDirective)),
        reason:
            'Light and dark ColorSchemes must produce different '
            'init directives so the renderer cache buckets them '
            'separately and the user sees the right palette per '
            'theme mode.',
      );
    });
  });
}
