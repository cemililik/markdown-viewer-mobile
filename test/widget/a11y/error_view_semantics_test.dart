import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/core/widgets/error_view.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

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

  testWidgets('error view is a live region with the message as label', (
    tester,
  ) async {
    const message = 'Something went wrong';
    await tester.pumpWidget(harness(message: message));
    await tester.pumpAndSettle();

    // The outer Semantics wraps the whole view as a live region so
    // screen readers announce the error without the user navigating to it.
    // We verify via the widget tree rather than the merged semantics node
    // because the Semantics container merges with its Text child into a
    // composite node that bySemanticsLabel cannot locate by label alone.
    final liveRegion = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.liveRegion == true &&
          w.properties.label == message,
    );

    expect(
      liveRegion,
      findsOneWidget,
      reason:
          'ErrorView must be a live region so screen readers announce the '
          'error message as soon as it appears on screen.',
    );
  });

  testWidgets('decorative error icon is excluded from the semantics tree', (
    tester,
  ) async {
    await tester.pumpWidget(harness(message: 'Oops'));
    await tester.pumpAndSettle();

    // The Icon is wrapped in ExcludeSemantics — it must not produce
    // a semantics node of its own.
    expect(
      find.bySemanticsLabel(RegExp('error|icon', caseSensitive: false)),
      findsNothing,
      reason:
          'The error icon is decorative and must not appear in the semantics '
          'tree; the message text already describes the failure.',
    );
  });

  testWidgets('retry button is reachable as a button when onRetry is set', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      harness(
        message: 'Failed',
        onRetry: () => tapped = true,
        retryLabel: 'Try again',
      ),
    );
    await tester.pumpAndSettle();

    final retryNode = tester.getSemantics(find.bySemanticsLabel('Try again'));

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
}
