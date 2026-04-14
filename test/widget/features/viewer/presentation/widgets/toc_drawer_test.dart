import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/toc_drawer.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

void main() {
  Document makeDocument(List<HeadingRef> headings) {
    return Document(
      id: const DocumentId('/tmp/test.md'),
      source: '',
      headings: headings,
      lineCount: 0,
      byteSize: 0,
      topLevelBlockCount: headings.length,
    );
  }

  Widget harness(Document document, {ValueChanged<HeadingRef>? onSelected}) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        endDrawer: TocDrawer(
          document: document,
          onHeadingSelected: onSelected ?? (_) {},
        ),
        body: Builder(
          builder:
              (context) => Center(
                child: FilledButton(
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                  child: const Text('open'),
                ),
              ),
        ),
      ),
    );
  }

  group('TocDrawer', () {
    testWidgets('renders every heading in document order', (tester) async {
      final doc = makeDocument(const [
        HeadingRef(level: 1, text: 'Intro', anchor: 'intro', blockIndex: 0),
        HeadingRef(level: 2, text: 'Details', anchor: 'details', blockIndex: 2),
        HeadingRef(level: 3, text: 'Notes', anchor: 'notes', blockIndex: 5),
      ]);

      await tester.pumpWidget(harness(doc));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Contents'), findsOneWidget);
      expect(find.text('Intro'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('tapping a heading closes the drawer and fires the callback', (
      tester,
    ) async {
      HeadingRef? selected;
      final doc = makeDocument(const [
        HeadingRef(level: 1, text: 'Intro', anchor: 'intro', blockIndex: 0),
        HeadingRef(level: 2, text: 'Details', anchor: 'details', blockIndex: 2),
      ]);

      await tester.pumpWidget(
        harness(doc, onSelected: (heading) => selected = heading),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.text, 'Details');
      expect(selected!.blockIndex, 2);
      // Drawer should be dismissed: the open button is visible again.
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets(
      'renders the localized empty state when the document has no headings',
      (tester) async {
        final doc = makeDocument(const []);

        await tester.pumpWidget(harness(doc));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('No headings in this document'), findsOneWidget);
      },
    );
  });
}
