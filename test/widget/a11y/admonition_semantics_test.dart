import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/application/markdown_extensions/admonition.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/admonition_view.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

import 'semantics_audit.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

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
    testWidgets(
      'should confirm that ${kind.name} admonition title has header semantics when the widget is exercised',
      (tester) async {
        await withSemanticsAudit(tester, () async {
          await tester.pumpWidget(harness(kind));
          await tester.pumpAndSettle();

          final title = titleForAdmonition(l10n, kind);
          final titleNode = tester.getSemantics(find.bySemanticsLabel(title));

          expect(
            titleNode,
            matchesSemantics(label: title, isHeader: true),
            reason:
                'Admonition "${kind.name}" title must carry isHeader so screen '
                'readers announce it as a section heading.',
          );
        });
      },
    );
  }

  testWidgets(
    'should confirm that admonition icon is excluded from the semantics tree when the widget is exercised',
    (tester) async {
      await withSemanticsAudit(tester, () async {
        await tester.pumpWidget(harness(AdmonitionKind.note));
        await tester.pumpAndSettle();

        expect(
          find.ancestor(
            of: find.byIcon(Icons.info_outline),
            matching: find.byType(ExcludeSemantics),
          ),
          findsOneWidget,
          reason:
              'The decorative icon must remain structurally excluded from '
              'semantics.',
        );
      });
    },
  );
}
