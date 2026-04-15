import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/application/markdown_extensions/admonition.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/admonition_view.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

void main() {
  Widget harness(AdmonitionKind kind) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AdmonitionView(
          kind: kind,
          body: const TextSpan(text: 'Body text'),
        ),
      ),
    );
  }

  for (final kind in AdmonitionKind.values) {
    testWidgets('${kind.name} admonition title has header semantics', (
      tester,
    ) async {
      await tester.pumpWidget(harness(kind));
      await tester.pumpAndSettle();

      // The title Text is wrapped in Semantics(header: true).
      // Find the semantics node that contains the title label.
      final titleNode = tester.getSemantics(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.header == true,
        ),
      );

      expect(
        titleNode,
        matchesSemantics(isHeader: true),
        reason:
            'Admonition "${kind.name}" title must carry isHeader so screen '
            'readers announce it as a section heading.',
      );
    });
  }

  testWidgets('admonition icon is excluded from the semantics tree', (
    tester,
  ) async {
    await tester.pumpWidget(harness(AdmonitionKind.note));
    await tester.pumpAndSettle();

    // There must be no semantics node for the decorative icon.
    // The icon is wrapped in ExcludeSemantics so it should not
    // appear as an image node in the tree.
    expect(
      find.bySemanticsLabel(RegExp('info|icon', caseSensitive: false)),
      findsNothing,
      reason:
          'The admonition icon is decorative and must not appear in the '
          'semantics tree.',
    );
  });
}
