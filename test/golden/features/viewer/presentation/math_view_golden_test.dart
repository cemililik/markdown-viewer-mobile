import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_helpers/golden_harness.dart';

void main() {
  group('Math view golden', () {
    goldenTest(
      'inline and display math blocks in light and dark themes',
      fileName: 'math_view',
      pumpBeforeTest: goldenPumpBeforeTest,
      pumpWidget: goldenPumpWidget,
      builder:
          () => GoldenTestGroup(
            children: [
              GoldenTestScenario(
                name: 'light',
                child: markdownGoldenHarness('math.md'),
              ),
              GoldenTestScenario(
                name: 'dark',
                child: markdownGoldenHarness(
                  'math.md',
                  brightness: Brightness.dark,
                ),
              ),
            ],
          ),
    );
  });
}
