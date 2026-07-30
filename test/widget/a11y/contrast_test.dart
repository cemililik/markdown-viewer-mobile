import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_highlighting/themes/atom-one-dark.dart' as hl_dark;
import 'package:flutter_highlighting/themes/atom-one-light.dart' as hl_light;
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/app/theme.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/markdown_view.dart';

void main() {
  group('application colour contrast', () {
    final themes = <String, ThemeData>{
      'light': AppTheme.light(null),
      'dark': AppTheme.dark(null),
      'sepia': AppTheme.sepia(),
    };

    for (final MapEntry(key: name, value: theme) in themes.entries) {
      test('should meet text and non-text contrast in the $name theme', () {
        final scheme = theme.colorScheme;

        expect(
          contrastRatio(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$name body text must meet WCAG AA.',
        );
        expect(
          contrastRatio(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$name secondary text must meet WCAG AA.',
        );
        expect(
          contrastRatio(scheme.primary, scheme.surface),
          greaterThanOrEqualTo(3),
          reason: '$name active controls must meet non-text contrast.',
        );
        expect(
          contrastRatio(scheme.error, scheme.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$name error text must meet WCAG AA.',
        );
      });
    }
  });

  group('syntax highlight contrast', () {
    final cases = <
      ({
        String name,
        Map<String, TextStyle> palette,
        ThemeData theme,
        Color background,
      })
    >[
      (
        name: 'light',
        palette: hl_light.atomOneLightTheme,
        theme: AppTheme.light(null),
        background: AppTheme.light(null).colorScheme.surfaceContainerLow,
      ),
      (
        name: 'dark',
        palette: hl_dark.atomOneDarkTheme,
        theme: AppTheme.dark(null),
        background: AppTheme.dark(null).colorScheme.surfaceContainerHigh,
      ),
      (
        name: 'sepia',
        palette: hl_light.atomOneLightTheme,
        theme: AppTheme.sepia(),
        background: AppTheme.sepia().colorScheme.surfaceContainerLow,
      ),
    ];

    for (final contrastCase in cases) {
      test('should keep every token at WCAG AA contrast in the '
          '${contrastCase.name} theme', () {
        final adjusted = ensureCodeThemeContrast(
          contrastCase.palette,
          background: contrastCase.background,
          fallback: contrastCase.theme.colorScheme.onSurface,
        );

        for (final MapEntry(key: token, value: style) in adjusted.entries) {
          final color = style.color;
          if (color == null) {
            continue;
          }
          expect(
            contrastRatio(color, contrastCase.background),
            greaterThanOrEqualTo(4.5),
            reason: '${contrastCase.name} token "$token" must meet WCAG AA.',
          );
        }
      });
    }
  });
}

double contrastRatio(Color foreground, Color background) {
  final opaqueForeground = Color.alphaBlend(foreground, background);
  final foregroundLuminance = opaqueForeground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = math.max(foregroundLuminance, backgroundLuminance);
  final darker = math.min(foregroundLuminance, backgroundLuminance);
  return (lighter + 0.05) / (darker + 0.05);
}
