import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

import '../../../_helpers/golden_harness.dart';

void main() {
  // `markdown_widget` leaves `TapGestureRecognizer` instances
  // undisposed for every inline link / footnote ref it renders. That
  // is an upstream package issue, not application code — ignore the
  // class for this golden file so its bug does not mask real leaks
  // elsewhere.
  LeakTesting.settings = LeakTesting.settings.withIgnored(
    classes: const ['TapGestureRecognizer'],
  );

  group('Admonitions golden', () {
    goldenTest(
      'note, warning, tip, and caution admonition blocks',
      fileName: 'admonitions',
      pumpBeforeTest: goldenPumpBeforeTest,
      pumpWidget: goldenPumpWidget,
      builder:
          () => GoldenTestGroup(
            children: [
              GoldenTestScenario(
                name: 'light',
                child: markdownGoldenHarness('admonitions.md'),
              ),
              GoldenTestScenario(
                name: 'dark',
                child: markdownGoldenHarness(
                  'admonitions.md',
                  brightness: Brightness.dark,
                ),
              ),
            ],
          ),
    );
  });
}
