import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

import '../../../_helpers/golden_harness.dart';

void main() {
  // Ignore `markdown_widget`'s undisposed `TapGestureRecognizer`
  // instances — see admonitions_golden_test.dart for the rationale.
  setUp(() {
    final original = LeakTesting.settings;
    LeakTesting.settings = original.withIgnored(
      classes: const ['TapGestureRecognizer'],
    );
    addTearDown(() => LeakTesting.settings = original);
  });

  group('GFM features golden', () {
    goldenTest(
      'should tables, task lists, strikethrough, and footnote refs',
      fileName: 'gfm_features',
      pumpBeforeTest: goldenPumpBeforeTest,
      pumpWidget: goldenPumpWidget,
      builder:
          () => GoldenTestGroup(
            children: standardGoldenScenarios(
              builder:
                  (locale, textScaler, brightness) => markdownGoldenHarness(
                    'gfm_features.md',
                    brightness: brightness,
                    locale: locale,
                    textScaler: textScaler,
                  ),
            ),
          ),
    );
  });
}
