import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_helpers/golden_harness.dart';

void main() {
  group('Headings golden', () {
    goldenTest(
      'should heading levels render correctly in light and dark themes',
      fileName: 'headings',
      pumpBeforeTest: goldenPumpBeforeTest,
      pumpWidget: goldenPumpWidget,
      builder:
          () => GoldenTestGroup(
            children: standardGoldenScenarios(
              builder:
                  (locale, textScaler, brightness) => markdownGoldenHarness(
                    'headings.md',
                    brightness: brightness,
                    locale: locale,
                    textScaler: textScaler,
                  ),
            ),
          ),
    );
  });
}
