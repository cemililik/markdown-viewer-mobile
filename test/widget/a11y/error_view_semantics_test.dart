import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/core/widgets/error_view.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

import 'semantics_audit.dart';

void main() {
  Widget harness({
    required String message,
    VoidCallback? onRetry,
    String? retryLabel,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ErrorView(
          message: message,
          onRetry: onRetry,
          retryLabel: retryLabel,
        ),
      ),
    );
  }

  testWidgets('should error view is a live region with the message as label', (
    tester,
  ) async {
    await withSemanticsAudit(tester, () async {
      const message = 'Something went wrong';
      await tester.pumpWidget(harness(message: message));
      await tester.pumpAndSettle();

      // The live-region container intentionally delegates its accessible text
      // to the child to prevent duplicate VoiceOver and TalkBack announcements.
      final liveRegion = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      );
      expect(
        liveRegion,
        findsOneWidget,
        reason:
            'ErrorView must be a live region so screen readers announce the '
            'error message as soon as it appears on screen.',
      );
      expect(
        find.bySemanticsLabel(message),
        findsOneWidget,
        reason:
            'The error message must be readable by screen readers via the '
            'child Text widget — not duplicated on the Semantics container.',
      );
    });
  });

  testWidgets(
    'should decorative error icon is excluded from the semantics tree',
    (tester) async {
      await withSemanticsAudit(tester, () async {
        await tester.pumpWidget(harness(message: 'Oops'));
        await tester.pumpAndSettle();

        expect(
          find.ancestor(
            of: find.byIcon(Icons.error_outline),
            matching: find.byType(ExcludeSemantics),
          ),
          findsOneWidget,
          reason:
              'The decorative error icon must remain structurally excluded '
              'from semantics.',
        );
      });
    },
  );

  testWidgets(
    'should retry button is reachable as a button when onRetry is set',
    (tester) async {
      await withSemanticsAudit(tester, () async {
        var tapped = false;
        await tester.pumpWidget(
          harness(
            message: 'Failed',
            onRetry: () => tapped = true,
            retryLabel: 'Try again',
          ),
        );
        await tester.pumpAndSettle();

        final retryNode = tester.getSemantics(
          find.bySemanticsLabel('Try again'),
        );

        expect(
          retryNode,
          matchesSemantics(
            label: 'Try again',
            hasTapAction: true,
            hasFocusAction: true,
            isButton: true,
            isFocusable: true,
            hasEnabledState: true,
            isEnabled: true,
          ),
          reason:
              'The retry button must have button semantics so screen readers '
              'announce the tap affordance alongside the label.',
        );

        await tester.tap(find.bySemanticsLabel('Try again'));
        expect(tapped, isTrue);
      });
    },
  );
}
