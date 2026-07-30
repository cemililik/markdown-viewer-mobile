import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sourceFiles = [
    ..._dartFiles(Directory('test')),
    ..._dartFiles(Directory('integration_test')),
  ];

  test(
    'should name every test as an observable expectation when the behavior is exercised',
    () {
      final violations = <String>[];

      for (final file in sourceFiles) {
        final source = file.readAsStringSync();
        for (final declaration in _testDeclarations(source)) {
          if (!RegExp(
            r'^should \S.*\swhen\s\S.*$',
            dotAll: true,
          ).hasMatch(declaration.description)) {
            violations.add(
              '${file.path}:${_lineNumber(source, declaration.offset)} '
              '"${declaration.description}"',
            );
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Test descriptions must use '
            '"should <expected behavior> when <condition>":\n'
            '${violations.join('\n')}',
      );
    },
  );

  test('should reject localized copy in text finders when tests are scanned', () {
    final localizedSamples =
        Directory('lib/l10n')
            .listSync()
            .whereType<File>()
            .where((file) => RegExp(r'app_[a-z]+\.arb$').hasMatch(file.path))
            .expand((file) {
              final arb =
                  jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
              return _localizedMessageSamples(arb);
            })
            .toSet();
    final violations = <String>[];
    final directLiteralFinder = RegExp(
      r'''\bfind\.(text|textContaining|byTooltip|bySemanticsLabel)\(\s*r?(['"])(.*?)\2''',
      multiLine: true,
    );
    final widgetWithLiteralText = RegExp(
      r'''\bfind\.(widgetWithText)\([^,]+,\s*r?(['"])(.*?)\2''',
      multiLine: true,
    );
    final dynamicTextFinder = RegExp(
      r'''\bfind\.text\(\s*(?!r?['"])|\bfind\.widgetWithText\([^,]+,\s*(?!r?['"])''',
      multiLine: true,
    );
    final localizedTextContaining = RegExp(
      r'''\bfind\.textContaining\(\s*(?:_?l10n|en|tr)\.''',
      multiLine: true,
    );

    for (final file in sourceFiles) {
      final source = file.readAsStringSync();
      final matches = [
        ...directLiteralFinder.allMatches(source),
        ...widgetWithLiteralText.allMatches(source),
      ];
      for (final match in matches) {
        final finder = match.group(1)!;
        final literal = match.group(3)!;
        final matchesLocalizedCopy =
            localizedSamples.contains(literal) ||
            (finder == 'textContaining' &&
                literal.length >= 8 &&
                localizedSamples.any((sample) => sample.contains(literal)));
        if (matchesLocalizedCopy) {
          violations.add(
            '${file.path}:${_lineNumber(source, match.start)} "$literal"',
          );
        }
      }
      for (final match in dynamicTextFinder.allMatches(source)) {
        violations.add(
          '${file.path}:${_lineNumber(source, match.start)} '
          'dynamic text finder',
        );
      }
      for (final match in localizedTextContaining.allMatches(source)) {
        violations.add(
          '${file.path}:${_lineNumber(source, match.start)} '
          'localized textContaining finder',
        );
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

  test(
    'should parse raw and adjacent test descriptions when declarations are inspected',
    () {
      const rawPrefix = 'r';
      final declarations =
          _testDeclarations(
            "test($rawPrefix'should stay valid ' "
            "'when raw strings are used', () {})",
          ).toList();

      expect(declarations, hasLength(1));
      expect(
        declarations.single.description,
        'should stay valid when raw strings are used',
      );
    },
  );

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

Iterable<({String description, int offset})> _testDeclarations(
  String source,
) sync* {
  final starts = RegExp(
    r'\b(?:test|testWidgets|goldenTest)\s*\(',
  ).allMatches(source);
  for (final start in starts) {
    var cursor = _skipWhitespace(source, start.end);
    final description = StringBuffer();
    var parsedAny = false;
    while (true) {
      final token = _parseStringLiteral(source, cursor);
      if (token == null) break;
      parsedAny = true;
      description.write(token.content);
      cursor = _skipWhitespace(source, token.end);
    }
    if (parsedAny) {
      yield (description: description.toString(), offset: start.start);
    }
  }
}

({String content, int end})? _parseStringLiteral(String source, int start) {
  var cursor = start;
  var raw = false;
  if (cursor + 1 < source.length &&
      (source[cursor] == 'r' || source[cursor] == 'R') &&
      (source[cursor + 1] == "'" || source[cursor + 1] == '"')) {
    raw = true;
    cursor += 1;
  }
  if (cursor >= source.length ||
      (source[cursor] != "'" && source[cursor] != '"')) {
    return null;
  }

  final quote = source[cursor];
  final delimiter = source.startsWith(quote * 3, cursor) ? quote * 3 : quote;
  final contentStart = cursor + delimiter.length;
  cursor = contentStart;
  while (cursor < source.length) {
    if (source.startsWith(delimiter, cursor)) {
      return (
        content: source.substring(contentStart, cursor),
        end: cursor + delimiter.length,
      );
    }
    cursor += !raw && source[cursor] == r'\' ? 2 : 1;
  }
  return null;
}

int _skipWhitespace(String source, int start) {
  var cursor = start;
  while (cursor < source.length && RegExp(r'\s').hasMatch(source[cursor])) {
    cursor += 1;
  }
  return cursor;
}

Iterable<String> _localizedMessageSamples(Map<String, Object?> arb) sync* {
  for (final entry in arb.entries) {
    if (entry.key.startsWith('@') || entry.value is! String) continue;
    final message = entry.value! as String;
    final metadata = arb['@${entry.key}'];
    final examples = <String, String>{};
    if (metadata is Map<String, Object?>) {
      final placeholders = metadata['placeholders'];
      if (placeholders is Map<String, Object?>) {
        for (final placeholder in placeholders.entries) {
          final declaration = placeholder.value;
          if (declaration is Map<String, Object?>) {
            examples[placeholder.key] =
                declaration['example']?.toString() ?? '2';
          }
        }
      }
    }

    final pluralBranches = _pluralBranchBodies(message);
    if (pluralBranches.isEmpty) {
      yield _replacePlaceholders(message, examples);
    } else {
      for (final branch in pluralBranches) {
        yield _replacePlaceholders(branch, examples);
      }
    }
  }
}

List<String> _pluralBranchBodies(String message) {
  final bodies = <String>[];
  final branch = RegExp(r'(?:=\d+|zero|one|two|few|many|other)\s*\{');
  for (final match in branch.allMatches(message)) {
    var depth = 1;
    var cursor = match.end;
    while (cursor < message.length && depth > 0) {
      if (message[cursor] == '{') depth += 1;
      if (message[cursor] == '}') depth -= 1;
      cursor += 1;
    }
    if (depth == 0) {
      bodies.add(message.substring(match.end, cursor - 1));
    }
  }
  return bodies;
}

String _replacePlaceholders(String message, Map<String, String> examples) =>
    message.replaceAllMapped(
      RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}'),
      (match) => examples[match.group(1)] ?? '2',
    );
