import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/toc_drawer.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

void main() {
  Widget harness({
    required List<HeadingRef> headings,
    void Function(HeadingRef)? onHeadingSelected,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        endDrawer: TocDrawer(
          document: Document(
            id: const DocumentId('test'),
            source: '',
            headings: headings,
            lineCount: 0,
            byteSize: 0,
            topLevelBlockCount: 0,
          ),
          onHeadingSelected: onHeadingSelected ?? (_) {},
        ),
      ),
    );
  }

  testWidgets(
    'each heading entry has button semantics and the heading text as label',
    (tester) async {
      final headings = [
        const HeadingRef(
          text: 'Introduction',
          level: 1,
          anchor: 'introduction',
          blockIndex: 0,
        ),
        const HeadingRef(
          text: 'Getting Started',
          level: 2,
          anchor: 'getting-started',
          blockIndex: 1,
        ),
        const HeadingRef(
          text: 'Advanced Usage',
          level: 3,
          anchor: 'advanced-usage',
          blockIndex: 2,
        ),
      ];

      await tester.pumpWidget(harness(headings: headings));
      // Open the end drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openEndDrawer();
      await tester.pumpAndSettle();

      // Every heading entry must be reachable as a button with its text as label.
      for (final heading in headings) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(heading.text)),
          matchesSemantics(
            label: heading.text,
            hasTapAction: true,
            hasFocusAction: true,
            isButton: true,
            isFocusable: true,
          ),
          reason:
              'TOC entry "${heading.text}" must have button semantics and its '
              'text as the semantic label so screen readers announce both the '
              'heading name and the tap affordance.',
        );
      }
    },
  );

  testWidgets('empty-document state renders a localized hint text', (
    tester,
  ) async {
    await tester.pumpWidget(harness(headings: const []));
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openEndDrawer();
    await tester.pumpAndSettle();

    expect(find.byType(TocDrawer), findsOneWidget);
  });
}
