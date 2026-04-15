import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:markdown_viewer/features/viewer/data/parsers/markdown_parser.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/markdown_view.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Rendering-pipeline performance benchmarks.
///
/// Each test measures a distinct stage of the pipeline described in
/// `docs/rendering-pipeline.md` and asserts that the measured time
/// does not exceed the budget documented there.
///
/// Run on a device or simulator:
///
///   flutter test integration_test/benchmark/render_benchmark_test.dart -d `<id>`
///
/// Budgets (from docs/rendering-pipeline.md):
///
/// | Stage                         | Budget  |
/// |-------------------------------|---------|
/// | Decode + Parse (1 MB)         | < 200 ms |
/// | Widget Build (1 MB)           | < 150 ms |
/// | Code Highlight (1 k lines)    | < 50 ms  |
///
/// Mermaid render (< 800 ms cold) is covered separately in
/// `integration_test/mermaid_render_test.dart` because it requires a
/// live WebView and is measured together with prewarm.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final originalUpdateInterval =
      VisibilityDetectorController.instance.updateInterval;
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  tearDownAll(() {
    VisibilityDetectorController.instance.updateInterval =
        originalUpdateInterval;
  });

  const MarkdownParser parser = MarkdownParser();

  // ── Fixtures generated in-memory ────────────────────────────────────

  /// Generates a synthetic markdown document of approximately [targetKb]
  /// kilobytes consisting of headings, paragraphs, and short lists.
  /// Avoids committing a large binary fixture to the repository while
  /// still exercising the parser on realistically sized input.
  Uint8List generateLargeMarkdown({int targetKb = 1024}) {
    final sb = StringBuffer();
    const para =
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed '
        'do eiusmod tempor incididunt ut labore et dolore magna aliqua. '
        'Ut enim ad minim veniam, quis nostrud exercitation ullamco '
        'laboris nisi ut aliquip ex ea commodo consequat.\n\n';

    var section = 0;
    while (sb.length < targetKb * 1024) {
      sb
        ..writeln('## Section ${++section}')
        ..writeln()
        ..write(para)
        ..write(para)
        ..writeln('- Item A')
        ..writeln('- Item B')
        ..writeln('- Item C')
        ..writeln();
    }
    return Uint8List.fromList(sb.toString().codeUnits);
  }

  /// Generates a markdown document containing a single fenced Dart
  /// code block with approximately [lineCount] lines — enough to
  /// stress-test the `re_highlight` tokeniser in isolation.
  Uint8List generateCodeHeavyMarkdown({int lineCount = 1000}) {
    final sb =
        StringBuffer()
          ..writeln('# Code Highlight Benchmark')
          ..writeln()
          ..writeln('```dart');
    for (var i = 0; i < lineCount; i++) {
      // Realistic Dart lines: variable declarations with various
      // types so the tokeniser sees keyword, identifier, and
      // punctuation tokens on every line.
      sb.writeln('  final String field$i = \'value_$i\'; // line $i');
    }
    sb
      ..writeln('```')
      ..writeln();
    return Uint8List.fromList(sb.toString().codeUnits);
  }

  // ── Decode + Parse ──────────────────────────────────────────────────

  group('Decode + Parse benchmark', () {
    test('parses a ~1 MB document in under 200 ms', () {
      final bytes = generateLargeMarkdown(targetKb: 1024);

      final stopwatch = Stopwatch()..start();
      final doc = parser.parse(
        id: const DocumentId('benchmark/large'),
        bytes: bytes,
      );
      stopwatch.stop();

      // ignore: avoid_print
      print(
        'Decode + Parse (${(bytes.length / 1024).round()} KB): '
        '${stopwatch.elapsedMilliseconds} ms  '
        '(${doc.lineCount} lines, ${doc.headings.length} headings)',
      );

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(200),
        reason:
            'Decode + Parse budget from docs/rendering-pipeline.md: '
            '< 200 ms for a 1 MB document on reference hardware.',
      );
    });
  });

  // ── Widget Build ────────────────────────────────────────────────────

  group('Widget Build benchmark', () {
    testWidgets('builds the widget tree for a ~1 MB document in under 150 ms', (
      tester,
    ) async {
      // Use a standard 390×844 (iPhone 14) logical-pixel viewport so
      // the layout pass mirrors a real device.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final bytes = generateLargeMarkdown(targetKb: 1024);
      final doc = parser.parse(
        id: const DocumentId('benchmark/large'),
        bytes: bytes,
      );

      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MarkdownView(document: doc)),
        ),
      );
      // One `pump` advances past the initial build frame.
      await tester.pump();
      stopwatch.stop();

      // ignore: avoid_print
      print('Widget Build (~1 MB doc): ${stopwatch.elapsedMilliseconds} ms');

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(150),
        reason:
            'Widget Build budget from docs/rendering-pipeline.md: '
            '< 150 ms for a 1 MB document on reference hardware.',
      );
    });
  });

  // ── Code Highlight ──────────────────────────────────────────────────

  group('Code Highlight benchmark', () {
    testWidgets('syntax-highlights a 1 000-line Dart block in under 50 ms', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final bytes = generateCodeHeavyMarkdown(lineCount: 1000);
      final doc = parser.parse(
        id: const DocumentId('benchmark/code'),
        bytes: bytes,
      );

      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MarkdownView(document: doc)),
        ),
      );
      await tester.pump();
      stopwatch.stop();

      // ignore: avoid_print
      print(
        'Code Highlight (1 000-line Dart block): '
        '${stopwatch.elapsedMilliseconds} ms',
      );

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(50),
        reason:
            'Code Highlight budget from docs/rendering-pipeline.md: '
            '< 50 ms for a 1 000-line block on reference hardware.',
      );
    });
  });
}
