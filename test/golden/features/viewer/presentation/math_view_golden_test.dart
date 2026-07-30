import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_helpers/golden_harness.dart';

void main() {
  group('Math view golden', () {
    goldenTest(
      'should render inline and display math blocks when captured',
      fileName: 'math_view',
      pumpBeforeTest: goldenPumpBeforeTest,
      pumpWidget: goldenPumpWidget,
      builder:
          () => GoldenTestGroup(
            children: standardGoldenScenarios(
              builder:
                  (locale, textScaler, appTheme) => markdownGoldenHarness(
                    'math.md',
                    appTheme: appTheme,
                    locale: locale,
                    textScaler: textScaler,
                  ),
            ),
          ),
    );
  });
}
