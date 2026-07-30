import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sourceFiles = [
    ..._dartFiles(Directory('test')),
    ..._dartFiles(Directory('integration_test')),
  ];

  test('should name every test as an observable expectation', () {
    final violations = <String>[];
    final declaration = RegExp(
      r'''\b(?:test|testWidgets|goldenTest)\(\s*(['"])(?!should\s)''',
      multiLine: true,
    );

    for (final file in sourceFiles) {
      final source = file.readAsStringSync();
      for (final match in declaration.allMatches(source)) {
        violations.add('${file.path}:${_lineNumber(source, match.start)}');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Test descriptions must start with "should":\n'
          '${violations.join('\n')}',
    );
  });

  test('should derive localized text finders from AppLocalizations', () {
    final localizedValues =
        Directory('lib/l10n')
            .listSync()
            .whereType<File>()
            .where((file) => RegExp(r'app_[a-z]+\.arb$').hasMatch(file.path))
            .expand(
              (file) =>
                  (jsonDecode(file.readAsStringSync()) as Map<String, Object?>)
                      .entries,
            )
            .where((entry) => !entry.key.startsWith('@'))
            .map((entry) => entry.value)
            .whereType<String>()
            .where((value) => !value.contains('{'))
            .toSet();
    final violations = <String>[];
    final directLiteralFinder = RegExp(
      r'''\bfind\.(?:text|textContaining|byTooltip|bySemanticsLabel)\(\s*(['"])(.*?)\1''',
      multiLine: true,
    );
    final widgetWithLiteralText = RegExp(
      r'''\bfind\.widgetWithText\([^,]+,\s*(['"])(.*?)\1''',
      multiLine: true,
    );

    for (final file in sourceFiles) {
      final source = file.readAsStringSync();
      final matches = [
        ...directLiteralFinder.allMatches(source),
        ...widgetWithLiteralText.allMatches(source),
      ];
      for (final match in matches) {
        final literal = match.group(2)!;
        if (localizedValues.contains(literal)) {
          violations.add(
            '${file.path}:${_lineNumber(source, match.start)} "$literal"',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Localized finders must use AppLocalizations getters:\n'
          '${violations.join('\n')}',
    );
  });

  test('should report diagnostics only when a test fails', () {
    final violations = <String>[];
    final printCall = RegExp(r'(?<!printOnFailure)\bprint\(');

    for (final file in sourceFiles) {
      final source = file.readAsStringSync();
      for (final match in printCall.allMatches(source)) {
        violations.add('${file.path}:${_lineNumber(source, match.start)}');
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Use printOnFailure for deterministic diagnostics:\n'
          '${violations.join('\n')}',
    );
  });
}

Iterable<File> _dartFiles(Directory directory) sync* {
  if (!directory.existsSync()) {
    return;
  }
  yield* directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('_test.dart'));
}

int _lineNumber(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;
