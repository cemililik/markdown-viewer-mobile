import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_helpers/golden_harness.dart';

void main() {
  group('Headings golden', () {
    goldenTest(
      'should render heading levels correctly when captured',
      fileName: 'headings',
      tags: const ['golden'],
      pumpBeforeTest: goldenPumpBeforeTest,
      pumpWidget: goldenPumpWidget,
      builder:
          () => GoldenTestGroup(
            children: standardGoldenScenarios(
              builder:
                  (locale, textScaler, appTheme) => markdownGoldenHarness(
                    'headings.md',
                    appTheme: appTheme,
                    locale: locale,
                    textScaler: textScaler,
                  ),
            ),
          ),
    );
  });
}
