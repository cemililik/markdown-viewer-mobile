import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

import '../../../_helpers/golden_harness.dart';

void main() {
  // `markdown_widget` leaves `TapGestureRecognizer` instances
  // undisposed for every inline link / footnote ref it renders. That
  // is an upstream package issue, not application code — ignore the
  // class for this golden file so its bug does not mask real leaks
  // elsewhere.
  setUp(() {
    final original = LeakTesting.settings;
    LeakTesting.settings = original.withIgnored(
      classes: const ['TapGestureRecognizer'],
    );
    addTearDown(() => LeakTesting.settings = original);
  });

  group('Admonitions golden', () {
    goldenTest(
      'should note, warning, tip, and caution admonition blocks',
      fileName: 'admonitions',
      pumpBeforeTest: goldenPumpBeforeTest,
      pumpWidget: goldenPumpWidget,
      builder:
          () => GoldenTestGroup(
            children: standardGoldenScenarios(
              builder:
                  (locale, textScaler, brightness) => markdownGoldenHarness(
                    'admonitions.md',
                    brightness: brightness,
                    locale: locale,
                    textScaler: textScaler,
                  ),
            ),
          ),
    );
  });
}
