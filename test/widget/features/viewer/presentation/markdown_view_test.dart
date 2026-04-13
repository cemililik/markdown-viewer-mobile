import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/markdown_view.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../_helpers/markdown_fixtures.dart';

void main() {
  // `markdown_widget` paints content through `visibility_detector`,
  // which schedules a 500 ms debounce timer that flutter_test's fake
  // clock would otherwise leak. Collapse the debounce to zero for the
  // duration of this file and restore it on tearDown so we don't
  // pollute any later test that loads the same singleton.
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalUpdateInterval =
      VisibilityDetectorController.instance.updateInterval;
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  tearDownAll(() {
    VisibilityDetectorController.instance.updateInterval =
        originalUpdateInterval;
  });

  Document parseFixture(String name) => parseMarkdownFixture(name);

  /// Resizes the test surface to a tall window before each test runs
  /// and resets it on tear-down. `MarkdownWidget` is internally backed
  /// by a `ListView`, which builds children lazily — items below the
  /// default 800×600 viewport are simply never instantiated, and any
  /// `find.textContaining(...)` against them returns zero matches.
  /// Giving each test a 1200×4000 surface forces the whole document
  /// into the build tree so the assertions can see every block.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget harness(
    Document document, {
    Brightness brightness = Brightness.light,
  }) {
    // MarkdownWidget contains its own internal ListView, so the body
    // just hosts it directly — wrapping with another scrollable would
    // crash with "vertical viewport given unbounded height".
    return MaterialApp(
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      home: Scaffold(body: MarkdownView(document: document)),
    );
  }

  /// Recursively walks the [InlineSpan] tree under [span] and counts how
  /// many leaf [TextSpan]s it contains. A code block that has been
  /// syntax-highlighted gets one TextSpan per token, so a leaf count
  /// well above 1 is a strong proof that highlighting actually fired.
  int countTextSpans(InlineSpan span) {
    var count = 0;
    span.visitChildren((child) {
      if (child is TextSpan && child.children == null) {
        count += 1;
      }
      return true;
    });
    return count;
  }

  group('MarkdownView code blocks', () {
    testWidgets('renders Dart fence with multiple highlighted spans', (
      tester,
    ) async {
      useTallSurface(tester);
      final doc = parseFixture('code_blocks.md');

      await tester.pumpWidget(harness(doc));
      await tester.pumpAndSettle();

      // The Dart sample contains the literal "void main()". A
      // RichText that contains it must exist somewhere in the tree.
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final dartRichText = richTexts.firstWhere(
        (rt) => rt.text.toPlainText().contains('void main()'),
        orElse:
            () =>
                throw StateError(
                  'No RichText found that contains the Dart sample text',
                ),
      );

      final spanCount = countTextSpans(dartRichText.text);
      expect(
        spanCount,
        greaterThan(1),
        reason:
            'A highlighted Dart fence must tokenise into multiple '
            'TextSpans. A leaf-span count of 1 means the highlighter '
            'never ran and the entire fence body collapsed into a '
            'single styled blob — got $spanCount.',
      );
    });

    testWidgets('falls back gracefully on an unknown language', (tester) async {
      useTallSurface(tester);
      final doc = parseFixture('code_blocks.md');

      await tester.pumpWidget(harness(doc));
      await tester.pumpAndSettle();

      // The fictional-lang fence is upper-case so it can't collide
      // with a real keyword the highlighter might still recognise.
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final fallback = richTexts.where(
        (rt) => rt.text.toPlainText().contains(
          'THIS IS PLAIN TEXT THAT MUST FALL BACK GRACEFULLY',
        ),
      );
      expect(
        fallback,
        isNotEmpty,
        reason: 'Unknown-language fence must still render its body verbatim.',
      );
    });

    testWidgets('renders the same content in dark theme without crashing', (
      tester,
    ) async {
      useTallSurface(tester);
      // Regression guard: the dark `PreConfig` path uses different
      // colours and a different highlight theme map. A typo there
      // would only show up the first time someone flips the theme.
      final doc = parseFixture('code_blocks.md');

      await tester.pumpWidget(harness(doc, brightness: Brightness.dark));
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownView), findsOneWidget);
      expect(
        find.textContaining('void main()', findRichText: true),
        findsOneWidget,
      );
    });
  });

  group('MarkdownView GFM features', () {
    testWidgets('renders table headers and body cells as text nodes', (
      tester,
    ) async {
      useTallSurface(tester);
      final doc = parseFixture('gfm_features.md');

      await tester.pumpWidget(harness(doc));
      await tester.pumpAndSettle();

      // Header row
      expect(find.textContaining('Tier', findRichText: true), findsOneWidget);
      expect(
        find.textContaining('Latency', findRichText: true),
        findsOneWidget,
      );
      // Body cells
      expect(find.textContaining('Local', findRichText: true), findsOneWidget);
      expect(find.textContaining('500 ms', findRichText: true), findsOneWidget);
    });

    testWidgets('renders task list checkboxes', (tester) async {
      useTallSurface(tester);
      final doc = parseFixture('gfm_features.md');

      await tester.pumpWidget(harness(doc));
      await tester.pumpAndSettle();

      // markdown_widget renders task-list items as `Icon` widgets
      // (Icons.check_box / Icons.check_box_outline_blank) inside its
      // own `MCheckBox` wrapper, not as the Material `Checkbox`. The
      // fixture has 4 list items: 2 checked, 2 unchecked.
      expect(find.byIcon(Icons.check_box), findsNWidgets(2));
      expect(find.byIcon(Icons.check_box_outline_blank), findsNWidgets(2));
    });

    testWidgets('renders footnote bodies in the document tree', (tester) async {
      useTallSurface(tester);
      final doc = parseFixture('gfm_features.md');

      await tester.pumpWidget(harness(doc));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('First footnote body', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Second footnote body', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('renders strikethrough text without dropping characters', (
      tester,
    ) async {
      useTallSurface(tester);
      final doc = parseFixture('gfm_features.md');

      await tester.pumpWidget(harness(doc));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('struck-out', findRichText: true),
        findsOneWidget,
      );
    });
  });
}
