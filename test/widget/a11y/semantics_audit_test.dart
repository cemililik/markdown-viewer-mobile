import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'semantics_audit.dart';

void main() {
  testWidgets(
    'should reject a small pointer target when outer semantics claim 48 dp',
    (tester) async {
      await withSemanticsAudit(tester, () async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: Semantics(
                button: true,
                label: 'Misleading target',
                onTap: () {},
                child: SizedBox.square(
                  dimension: 48,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {},
                      child: const SizedBox.square(dimension: 24),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(
          () => expectTapTargetsAtLeast(tester),
          throwsA(isA<TestFailure>()),
        );
      });
    },
  );
}
