import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_helpers/golden_harness.dart';

void main() {
  group('Code blocks golden', () {
    goldenTest(
      'should syntax-highlighted fenced code blocks in light and dark themes',
      fileName: 'code_blocks',
      pumpBeforeTest: goldenPumpBeforeTest,
      pumpWidget: goldenPumpWidget,
      builder:
          () => GoldenTestGroup(
            children: standardGoldenScenarios(
              builder:
                  (locale, textScaler, brightness) => markdownGoldenHarness(
                    'code_blocks.md',
                    brightness: brightness,
                    locale: locale,
                    textScaler: textScaler,
                  ),
            ),
          ),
    );
  });
}
