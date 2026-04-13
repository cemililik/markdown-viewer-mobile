import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/data/parsers/markdown_parser.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/markdown_view.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/math_view.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  // Same VisibilityDetector workaround as the other markdown_widget
  // widget tests: collapse the debounce to zero during the run and
  // restore it on teardown so a later file does not inherit the
  // mutation.
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalUpdateInterval =
      VisibilityDetectorController.instance.updateInterval;
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  tearDownAll(() {
    VisibilityDetectorController.instance.updateInterval =
        originalUpdateInterval;
  });

  const parser = MarkdownParser();

  Document parseFixture(String name) {
    // Read as raw bytes so non-ASCII characters like `…` survive
    // round-tripping through `MarkdownParser._decode`. `String.codeUnits`
    // returns UTF-16 code units and would trip the parser's UTF-8
    // decoder on any multibyte glyph.
    final bytes = File('test/fixtures/markdown/$name').readAsBytesSync();
    return parser.parse(
      id: DocumentId('test/fixtures/markdown/$name'),
      bytes: bytes,
    );
  }

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget standaloneHarness(Widget child) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(body: Center(child: child)),
    );
  }

  Widget markdownHarness(Document document) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(body: MarkdownView(document: document)),
    );
  }

  group('MathView', () {
    testWidgets('renders a valid inline expression as a Math widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        standaloneHarness(const MathView.inline(expression: 'E = mc^2')),
      );
      await tester.pumpAndSettle();

      // On the success path Math.tex builds a real Math widget; on
      // the failure path it builds our _MathErrorFallback, which
      // contains a Container with the raw expression as text. If a
      // Math widget is in the tree, the expression was parsed.
      expect(find.byType(Math), findsOneWidget);
      expect(
        find.textContaining('E = mc^2', findRichText: true),
        findsNothing,
        reason:
            'A valid inline expression should render as typeset math, '
            'not fall back to the raw-TeX error placeholder.',
      );
    });

    testWidgets('renders a valid display expression with horizontal scroll', (
      tester,
    ) async {
      await tester.pumpWidget(
        standaloneHarness(const MathView.display(expression: r'\frac{a}{b}')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Math), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets(
      'falls back to an inline error placeholder on malformed input',
      (tester) async {
        const malformed = r'\frac{1}{';
        await tester.pumpWidget(
          standaloneHarness(const MathView.inline(expression: malformed)),
        );
        await tester.pumpAndSettle();

        // The `Math` widget is always in the tree — the error
        // fallback is returned from `Math.build`, so the outer
        // widget element is still present. Proof that the fallback
        // fired is that the raw TeX source appears as a plain Text
        // node (the success branch renders typeset glyphs, not the
        // raw characters). The document also stays laid out — no
        // assertion failure from a thrown exception.
        expect(
          find.textContaining(malformed, findRichText: true),
          findsOneWidget,
          reason:
              'Malformed math must take the onErrorFallback branch and '
              'render the raw TeX source in the error placeholder, not '
              'attempt to typeset it.',
        );
      },
    );
  });

  group('MarkdownView math integration', () {
    testWidgets(
      'inline `\$ … \$` in a paragraph reaches the rendered tree as Math',
      (tester) async {
        useTallSurface(tester);
        final doc = parseFixture('math.md');

        await tester.pumpWidget(markdownHarness(doc));
        await tester.pumpAndSettle();

        // The fixture has many inline expressions. We only need to
        // prove at least one made it through the custom generator
        // pipeline and ended up as a flutter_math_fork `Math`.
        expect(find.byType(Math), findsWidgets);
      },
    );

    testWidgets('malformed math in the fixture does not crash the viewer', (
      tester,
    ) async {
      useTallSurface(tester);
      final doc = parseFixture('math.md');

      await tester.pumpWidget(markdownHarness(doc));
      await tester.pumpAndSettle();

      // A successfully rendered fixture means the malformed
      // expressions each took the onErrorFallback path instead of
      // throwing out of the build. The rest of the document must
      // still be visible; pick a sentence that sits *after* the
      // broken blocks as a regression marker.
      expect(
        find.textContaining(
          'The document keeps rendering after the broken blocks',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('literal dollar signs do not trigger math rendering', (
      tester,
    ) async {
      useTallSurface(tester);
      final doc = parseFixture('math.md');

      await tester.pumpWidget(markdownHarness(doc));
      await tester.pumpAndSettle();

      // The literal-dollar paragraph must surface as readable
      // prose. If the escape handling broke, the `$100` and `$5`
      // parts would be swallowed by a (broken) inline match.
      expect(find.textContaining(r'$100', findRichText: true), findsWidgets);
    });
  });
}
