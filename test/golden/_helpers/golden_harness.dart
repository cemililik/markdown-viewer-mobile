import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/markdown_view.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../_helpers/markdown_fixtures.dart';

export '../../_helpers/markdown_fixtures.dart';

/// Canonical viewport for every golden test: 390 × 844 logical pixels
/// at 1× DPR, matching an iPhone 14 form factor without multiplying
/// coordinates by a device-pixel ratio.
const Size kGoldenViewport = Size(390, 844);

/// Pump action used by every golden test in this project.
///
/// Collapses the [VisibilityDetector] debounce to zero (avoids the
/// pending-timer flutter_test warning) and calls `pumpAndSettle` so
/// all animations finish before the snapshot is taken.
Future<void> goldenPumpBeforeTest(WidgetTester tester) async {
  final original = VisibilityDetectorController.instance.updateInterval;
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  addTearDown(
    () => VisibilityDetectorController.instance.updateInterval = original,
  );
  await tester.pumpAndSettle();
}

/// Pump-widget action that pins the test surface to [kGoldenViewport]
/// before pumping. This keeps every golden at a deterministic size
/// regardless of the default test surface dimensions.
Future<void> goldenPumpWidget(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = kGoldenViewport;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(widget);
}

/// Builds a [MarkdownView] golden harness for a given fixture.
///
/// Alchemist renders each [GoldenTestScenario] child in an unconstrained
/// box (infinite height / width). [Scaffold] requires finite constraints
/// from its parent, so wrapping the entire [MaterialApp] in a [SizedBox]
/// matching [kGoldenViewport] gives the layout engine a concrete size.
///
/// [brightness] controls the theme; defaults to [Brightness.light].
Widget markdownGoldenHarness(
  String fixtureName, {
  Brightness brightness = Brightness.light,
}) {
  final doc = parseMarkdownFixture(fixtureName);
  return SizedBox(
    width: kGoldenViewport.width,
    height: kGoldenViewport.height,
    child: MaterialApp(
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: MarkdownView(document: doc)),
    ),
  );
}
