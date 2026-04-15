import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/markdown_view.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:markdown_widget/markdown_widget.dart' show Toc;
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../_helpers/markdown_fixtures.dart';

/// Regression tests for the TOC navigation path. The bug these
/// exist to catch: `HeadingRef.blockIndex` — computed by our own
/// `MarkdownParser` against `package:markdown`'s node list — can
/// drift out of sync with `markdown_widget`'s internal widget
/// index (which drives the `blockKeys` map). When the two
/// disagree, tapping a heading in the TOC drawer either scrolls
/// to the wrong place or silently fails (key lookup out of
/// range), leaving the user at the top of the document.
///
/// The fix wires `MarkdownView.onTocList` through to
/// `markdown_widget`'s `buildWidgets(onTocList: …)` callback,
/// which returns the authoritative `widgetIndex` for every
/// heading — identical by construction to the index used when
/// the render loop attaches `blockKeys`. These tests pin that
/// contract so a future refactor cannot quietly break TOC
/// navigation again.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalUpdateInterval =
      VisibilityDetectorController.instance.updateInterval;
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  tearDownAll(() {
    VisibilityDetectorController.instance.updateInterval =
        originalUpdateInterval;
  });

  Widget harness(
    Document document, {
    ValueChanged<List<Toc>>? onTocList,
    Map<int, GlobalKey>? blockKeys,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 1200,
          height: 4000,
          child: MarkdownView(
            document: document,
            blockKeys: blockKeys,
            onTocList: onTocList,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'onTocList fires with a widgetIndex for every heading in the document',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final document = parseMarkdownFixture('headings.md');
      // Sanity: the fixture has the heading count we expect.
      // Five visible headings: "Top Level", "Section One",
      // "Subsection 1.1", "Section Two", "Section One" (duplicate),
      // "Deepest". The parser also stamps `topLevelBlockCount`
      // but we deliberately DO NOT rely on it here — the whole
      // point of the fix is to stop coupling TOC navigation to
      // the parser-side count.
      expect(
        document.headings.length,
        greaterThanOrEqualTo(5),
        reason:
            'headings.md fixture must produce at least five TOC entries '
            'for this regression check to be meaningful',
      );

      List<Toc>? captured;
      await tester.pumpWidget(
        harness(document, onTocList: (tocs) => captured = tocs),
      );
      await tester.pump();

      expect(captured, isNotNull, reason: 'onTocList must fire during build');
      expect(
        captured!.length,
        document.headings.length,
        reason:
            'markdown_widget should surface one Toc entry per heading the '
            'parser discovered — if the two counts drift, TOC navigation '
            'starts mis-targeting',
      );
      for (var i = 0; i < captured!.length; i += 1) {
        expect(
          captured![i].widgetIndex,
          greaterThanOrEqualTo(0),
          reason: 'widgetIndex for heading $i must be non-negative',
        );
      }
    },
  );

  testWidgets(
    'blockKeys grows to cover every widgetIndex captured via onTocList',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final document = parseMarkdownFixture('headings.md');

      // Start with an empty map — the whole point of the lazy-grow
      // fix is that MarkdownView populates missing indices on demand.
      // If the fix regresses to the old pre-allocated pattern, this
      // expect will flag it: the map will stay small and any
      // widgetIndex above its length won't resolve to a valid key.
      final blockKeys = <int, GlobalKey>{};
      List<Toc>? captured;
      await tester.pumpWidget(
        harness(
          document,
          blockKeys: blockKeys,
          onTocList: (tocs) => captured = tocs,
        ),
      );
      await tester.pump();

      expect(captured, isNotNull);
      for (final toc in captured!) {
        final key = blockKeys[toc.widgetIndex];
        expect(
          key,
          isNotNull,
          reason:
              'every widgetIndex reported via onTocList must have a '
              'matching entry in blockKeys — if this fails, the render '
              'loop and the TOC navigation path are looking at different '
              'index spaces, which is exactly the bug this test guards',
        );
        expect(
          key!.currentContext,
          isNotNull,
          reason:
              'the key must be attached to a real widget context after '
              'the first pump — if currentContext is null, '
              'Scrollable.ensureVisible would silently fail and the user '
              'would appear stuck at the top of the document',
        );
      }
    },
  );
}
