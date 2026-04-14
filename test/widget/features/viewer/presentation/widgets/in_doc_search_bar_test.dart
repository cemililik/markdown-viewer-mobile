import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/in_doc_search_bar.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

void main() {
  Widget harness({
    required TextEditingController controller,
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
        appBar: AppBar(
          title: InDocSearchBar(
            controller: controller,
            focusNode: FocusNode(),
            matchCount: matchCount,
            currentMatchIndex: currentMatchIndex,
            onQueryChanged: onQueryChanged,
            onPrevious: onPrevious,
            onNext: onNext,
            onClose: onClose,
          ),
        ),
        body: const SizedBox.shrink(),
      ),
    );
  }

  group('InDocSearchBar', () {
    testWidgets('renders the field without a counter when the query is empty', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(
          controller: controller,
          matchCount: 0,
          currentMatchIndex: 0,
          onQueryChanged: (_) {},
          onPrevious: () {},
          onNext: () {},
          onClose: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search in document'), findsOneWidget);
      expect(find.text('No matches'), findsNothing);
    });

    testWidgets('shows the match counter when there are results', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'foo');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(
          controller: controller,
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
      expect(find.text('3 / 12'), findsOneWidget);
    });

    testWidgets('shows the no-results label when the query matches nothing', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'xyz');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(
          controller: controller,
          matchCount: 0,
          currentMatchIndex: 0,
          onQueryChanged: (_) {},
          onPrevious: () {},
          onNext: () {},
          onClose: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('chevrons are disabled while matchCount is zero', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'xyz');
      addTearDown(controller.dispose);
      var nextCalled = 0;
      var prevCalled = 0;
      await tester.pumpWidget(
        harness(
          controller: controller,
          matchCount: 0,
          currentMatchIndex: 0,
          onQueryChanged: (_) {},
          onPrevious: () => prevCalled += 1,
          onNext: () => nextCalled += 1,
          onClose: () {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Next match'));
      await tester.tap(find.byTooltip('Previous match'));
      await tester.pumpAndSettle();

      expect(nextCalled, 0);
      expect(prevCalled, 0);
    });

    testWidgets('tapping next / prev fires the callbacks', (tester) async {
      final controller = TextEditingController(text: 'foo');
      addTearDown(controller.dispose);
      var nextCalled = 0;
      var prevCalled = 0;
      await tester.pumpWidget(
        harness(
          controller: controller,
          matchCount: 5,
          currentMatchIndex: 1,
          onQueryChanged: (_) {},
          onPrevious: () => prevCalled += 1,
          onNext: () => nextCalled += 1,
          onClose: () {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Next match'));
      await tester.tap(find.byTooltip('Previous match'));
      await tester.pumpAndSettle();

      expect(nextCalled, 1);
      expect(prevCalled, 1);
    });
  });
}
