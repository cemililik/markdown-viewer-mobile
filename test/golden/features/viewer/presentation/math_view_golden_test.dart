import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_helpers/golden_harness.dart';

void main() {
  group('Math view golden', () {
    goldenTest(
      'should inline and display math blocks in light and dark themes',
      fileName: 'math_view',
      pumpBeforeTest: goldenPumpBeforeTest,
      pumpWidget: goldenPumpWidget,
      builder:
          () => GoldenTestGroup(
            children: standardGoldenScenarios(
              builder:
                  (locale, textScaler, brightness) => markdownGoldenHarness(
                    'math.md',
                    brightness: brightness,
                    locale: locale,
                    textScaler: textScaler,
                  ),
            ),
          ),
    );
  });
}
