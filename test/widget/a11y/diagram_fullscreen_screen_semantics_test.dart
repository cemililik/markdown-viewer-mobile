import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:markdown_viewer/features/viewer/presentation/screens/diagram_fullscreen_screen.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

import 'semantics_audit.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    final original = LeakTesting.settings;
    LeakTesting.settings = original.withIgnored(
      classes: const ['ImageStreamCompleterHandle', '_LiveImage'],
    );
    addTearDown(() => LeakTesting.settings = original);
  });

  testWidgets('should expose DiagramFullscreenScreen image and close control', (
    tester,
  ) async {
    await withSemanticsAudit(tester, () async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiagramFullscreenScreen(
            args: DiagramFullscreenArgs(
              pngBytes: base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
                'AAAAC0lEQVR42mNgAAIAAAUAAen63/AAAAAASUVORK5CYII=',
              ),
              width: 200,
              height: 100,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final image =
          tester
              .getSemantics(find.bySemanticsLabel(l10n.mermaidDiagramLabel))
              .getSemanticsData();
      expect(image.flagsCollection.isImage, isTrue);
      final imageSize = tester.getSize(find.byType(Image));
      expect(imageSize.width, greaterThan(0));
      expect(imageSize.height, greaterThan(0));

      final close =
          tester
              .getSemantics(
                find.bySemanticsLabel(l10n.diagramFullscreenCloseTooltip),
              )
              .getSemanticsData();
      expect(close.label, l10n.diagramFullscreenCloseTooltip);
      expect(close.flagsCollection.isButton, isTrue);
      expect(close.hasAction(SemanticsAction.tap), isTrue);

      expectEveryTapTargetLabeled(tester);
      expectTapTargetsAtLeast(tester);
    });
  });
}
