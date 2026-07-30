import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/viewer_search_bar.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Widget harness({
    required TextEditingController controller,
    required FocusNode focusNode,
    required int matchCount,
    required int currentMatchIndex,
    required ValueChanged<String> onQueryChanged,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
    required VoidCallback onClose,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox.shrink()),
            ViewerSearchBar(
              controller: controller,
              focusNode: focusNode,
              matchCount: matchCount,
              currentMatchIndex: currentMatchIndex,
              onQueryChanged: onQueryChanged,
              onPrevious: onPrevious,
              onNext: onNext,
              onClose: onClose,
            ),
          ],
        ),
      ),
    );
  }

  group('ViewerSearchBar', () {
    testWidgets(
      'should renders the field without a counter when the query is empty',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        await tester.pumpWidget(
          harness(
            controller: controller,
            focusNode: focusNode,
            matchCount: 0,
            currentMatchIndex: 0,
            onQueryChanged: (_) {},
            onPrevious: () {},
            onNext: () {},
            onClose: () {},
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.viewerSearchHint), findsOneWidget);
        expect(find.text(l10n.viewerSearchNoResults), findsNothing);
      },
    );

    testWidgets('should shows the match counter when there are results', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'foo');
      addTearDown(controller.dispose);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        harness(
          controller: controller,
          focusNode: focusNode,
          matchCount: 12,
          currentMatchIndex: 2,
          onQueryChanged: (_) {},
          onPrevious: () {},
          onNext: () {},
          onClose: () {},
        ),
      );
      await tester.pumpAndSettle();

      // 1-based counter: index 2 → "3 / 12"
      expect(find.text(l10n.viewerSearchMatchCount(3, 12)), findsOneWidget);
    });

    testWidgets(
      'should shows the no-results label when the query matches nothing',
      (tester) async {
        final controller = TextEditingController(text: 'xyz');
        addTearDown(controller.dispose);
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        await tester.pumpWidget(
          harness(
            controller: controller,
            focusNode: focusNode,
            matchCount: 0,
            currentMatchIndex: 0,
            onQueryChanged: (_) {},
            onPrevious: () {},
            onNext: () {},
            onClose: () {},
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.viewerSearchNoResults), findsOneWidget);
      },
    );

    testWidgets('should nav buttons are disabled while matchCount is zero', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'xyz');
      addTearDown(controller.dispose);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      var nextCalled = 0;
      var prevCalled = 0;
      await tester.pumpWidget(
        harness(
          controller: controller,
          focusNode: focusNode,
          matchCount: 0,
          currentMatchIndex: 0,
          onQueryChanged: (_) {},
          onPrevious: () => prevCalled += 1,
          onNext: () => nextCalled += 1,
          onClose: () {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(l10n.viewerSearchNextTooltip));
      await tester.tap(find.byTooltip(l10n.viewerSearchPreviousTooltip));
      await tester.pumpAndSettle();

      expect(nextCalled, 0);
      expect(prevCalled, 0);
    });

    testWidgets('should tapping next / prev fires the callbacks', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'foo');
      addTearDown(controller.dispose);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      var nextCalled = 0;
      var prevCalled = 0;
      await tester.pumpWidget(
        harness(
          controller: controller,
          focusNode: focusNode,
          matchCount: 5,
          currentMatchIndex: 1,
          onQueryChanged: (_) {},
          onPrevious: () => prevCalled += 1,
          onNext: () => nextCalled += 1,
          onClose: () {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(l10n.viewerSearchNextTooltip));
      await tester.tap(find.byTooltip(l10n.viewerSearchPreviousTooltip));
      await tester.pumpAndSettle();

      expect(nextCalled, 1);
      expect(prevCalled, 1);
    });
  });
}
