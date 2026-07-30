import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_helpers/golden_harness.dart';

void main() {
  group('Code blocks golden', () {
    goldenTest(
      'should render syntax-highlighted fenced code blocks when captured',
      fileName: 'code_blocks',
      pumpBeforeTest: goldenPumpBeforeTest,
      pumpWidget: goldenPumpWidget,
      builder:
          () => GoldenTestGroup(
            children: standardGoldenScenarios(
              builder:
                  (locale, textScaler, appTheme) => markdownGoldenHarness(
                    'code_blocks.md',
                    appTheme: appTheme,
                    locale: locale,
                    textScaler: textScaler,
                  ),
            ),
          ),
    );
  });
}
