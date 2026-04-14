import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_helpers/golden_harness.dart';

void main() {
  group('Code blocks golden', () {
    goldenTest(
      'syntax-highlighted fenced code blocks in light and dark themes',
      fileName: 'code_blocks',
      pumpBeforeTest: goldenPumpBeforeTest,
      pumpWidget: goldenPumpWidget,
      builder:
          () => GoldenTestGroup(
            children: [
              GoldenTestScenario(
                name: 'light',
                child: markdownGoldenHarness('code_blocks.md'),
              ),
              GoldenTestScenario(
                name: 'dark',
                child: markdownGoldenHarness(
                  'code_blocks.md',
                  brightness: Brightness.dark,
                ),
              ),
            ],
          ),
    );
  });
}
