import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

import '../../../_helpers/golden_harness.dart';

void main() {
  // Ignore `markdown_widget`'s undisposed `TapGestureRecognizer`
  // instances — see admonitions_golden_test.dart for the rationale.
  LeakTesting.settings = LeakTesting.settings.withIgnored(
    classes: const ['TapGestureRecognizer'],
  );

  group('GFM features golden', () {
    goldenTest(
      'tables, task lists, strikethrough, and footnote refs',
      fileName: 'gfm_features',
      pumpBeforeTest: goldenPumpBeforeTest,
      pumpWidget: goldenPumpWidget,
      builder:
          () => GoldenTestGroup(
            children: [
              GoldenTestScenario(
                name: 'light',
                child: markdownGoldenHarness('gfm_features.md'),
              ),
              GoldenTestScenario(
                name: 'dark',
                child: markdownGoldenHarness(
                  'gfm_features.md',
                  brightness: Brightness.dark,
                ),
              ),
            ],
          ),
    );
  });
}
