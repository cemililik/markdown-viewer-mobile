import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/markdown_view.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/math_view.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../_helpers/markdown_fixtures.dart';

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

  Document parseFixture(String name) => parseMarkdownFixture(name);

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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
      'inline `\$ … \$` in a paragraph reaches the rendered tree as inline Math',
      (tester) async {
        useTallSurface(tester);
        final doc = parseFixture('math.md');

        await tester.pumpWidget(markdownHarness(doc));
        await tester.pumpAndSettle();

        // The fixture contains BOTH inline (`$…$`) and display
        // (`$$…$$`) math, so a bare `find.byType(Math)` would pass
        // even if inline matching were broken. Filter the visible
        // Math widgets down to ones whose `mathStyle` is
        // `MathStyle.text` to prove that the inline pipeline (the
        // InlineMathSyntax parser + InlineMathSpanNode generator +
        // MathView.inline widget) is wired end-to-end.
        final inlineMaths = tester
            .widgetList<Math>(find.byType(Math))
            .where((m) => m.mathStyle == MathStyle.text);
        expect(
          inlineMaths,
          isNotEmpty,
          reason:
              'Inline math from `\$ … \$` must produce at least one '
              'flutter_math_fork Math widget with MathStyle.text. '
              'Display math `\$\$ … \$\$` is handled by a separate '
              'pipeline and would not satisfy this assertion.',
        );
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

    testWidgets(
      'math widget sizes are stable across scroll (no layout jitter)',
      (tester) async {
        // Render on a viewport that is deliberately shorter than the
        // document so a scroll is necessary to bring later math blocks
        // into view. A 390×700 surface at 1× DPR gives us a viewport
        // about half as tall as the full document.
        tester.view.physicalSize = const Size(390, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final doc = parseFixture('math.md');
        await tester.pumpWidget(markdownHarness(doc));
        await tester.pumpAndSettle();

        // Capture the render sizes of all Math widgets before scrolling.
        // `getSize` reads the element's RenderBox so it reflects the
        // actual laid-out pixel size, not a placeholder.
        final mathFinder = find.byType(Math);
        expect(
          mathFinder,
          findsWidgets,
          reason: 'math.md must contain at least one Math widget',
        );
        final sizesBeforeScroll =
            tester
                .widgetList<Math>(mathFinder)
                .map((widget) => tester.getSize(find.byWidget(widget)))
                .toList();

        // Scroll down by 300 logical pixels, settle, then scroll back.
        await tester.drag(find.byType(Scaffold), const Offset(0, -300));
        await tester.pumpAndSettle();

        await tester.drag(find.byType(Scaffold), const Offset(0, 300));
        await tester.pumpAndSettle();

        // Re-capture sizes after returning to the original scroll position.
        final sizesAfterScroll =
            tester
                .widgetList<Math>(mathFinder)
                .map((widget) => tester.getSize(find.byWidget(widget)))
                .toList();

        expect(
          sizesAfterScroll,
          equals(sizesBeforeScroll),
          reason:
              'Math widget sizes must be identical before and after a '
              'scroll round-trip. A size change indicates a layout '
              'reflow triggered by scroll state — the jitter regression '
              'this test guards against.',
        );
      },
    );
  });
}
