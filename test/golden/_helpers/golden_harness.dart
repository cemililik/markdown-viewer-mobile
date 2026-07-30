import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/app/theme.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/markdown_view.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../_helpers/markdown_fixtures.dart';

export '../../_helpers/markdown_fixtures.dart';

/// Canonical viewport for every golden test: 390 × 844 logical pixels
/// at 1× DPR, matching an iPhone 14 form factor without multiplying
/// coordinates by a device-pixel ratio.
const Size kGoldenViewport = Size(390, 844);

/// Application themes exercised by the canonical golden matrix.
enum GoldenAppTheme { light, dark, sepia }

/// Builds the project-wide locale, theme, and text-scale matrix.
List<GoldenTestScenario> standardGoldenScenarios({
  required Widget Function(
    Locale locale,
    TextScaler textScaler,
    GoldenAppTheme appTheme,
  )
  builder,
}) {
  const locales = <(String, Locale)>[
    ('en', Locale('en')),
    ('tr', Locale('tr')),
  ];
  const scales = <(String, TextScaler)>[
    ('1x', TextScaler.noScaling),
    ('2x', TextScaler.linear(2)),
  ];

  return [
    for (final (localeName, locale) in locales)
      for (final appTheme in GoldenAppTheme.values)
        for (final (scaleName, textScaler) in scales)
          GoldenTestScenario(
            name: '$localeName-${appTheme.name}-$scaleName',
            child: builder(locale, textScaler, appTheme),
          ),
  ];
}

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

/// Settles the widget tree and waits for every in-memory image to decode.
Future<void> goldenPumpBeforeTestWithImages(WidgetTester tester) async {
  await goldenPumpBeforeTest(tester);
  final imageElements = find.byType(Image).evaluate().toList();
  for (final element in imageElements) {
    final provider = (element.widget as Image).image;
    await tester.runAsync(() => precacheImage(provider, element));
  }
  await tester.pump();
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

/// Builds a deterministic localized application shell for screen goldens.
Widget goldenAppHarness({
  required Widget home,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  GoldenAppTheme appTheme = GoldenAppTheme.light,
}) {
  return SizedBox(
    width: kGoldenViewport.width,
    height: kGoldenViewport.height,
    child: MaterialApp(
      theme: _themeData(appTheme),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: textScaler, disableAnimations: true),
            child: child!,
          ),
      home: home,
    ),
  );
}

/// Builds a [MarkdownView] golden harness for a given fixture.
///
/// Alchemist renders each [GoldenTestScenario] child in an unconstrained
/// box (infinite height / width). [Scaffold] requires finite constraints
/// from its parent, so wrapping the entire [MaterialApp] in a [SizedBox]
/// matching [kGoldenViewport] gives the layout engine a concrete size.
///
/// [appTheme] controls the theme; defaults to [GoldenAppTheme.light].
Widget markdownGoldenHarness(
  String fixtureName, {
  GoldenAppTheme appTheme = GoldenAppTheme.light,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final doc = parseMarkdownFixture(fixtureName);
  return goldenAppHarness(
    appTheme: appTheme,
    locale: locale,
    textScaler: textScaler,
    home: ProviderScope(child: Scaffold(body: MarkdownView(document: doc))),
  );
}

ThemeData _themeData(GoldenAppTheme appTheme) => switch (appTheme) {
  GoldenAppTheme.light => AppTheme.light(null),
  GoldenAppTheme.dark => AppTheme.dark(null),
  GoldenAppTheme.sepia => AppTheme.sepia(),
};
