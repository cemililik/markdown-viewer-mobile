import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards message, placeholder, and plural-category parity between every ARB
/// locale file and the source-of-truth English file.
///
/// The pre-commit hook performs the same check to catch mistakes at
/// commit time; this test guarantees the check also runs in CI, per
/// `docs/standards/localization-standards.md`.
void main() {
  group('locale completeness', () {
    final arbDir = Directory('lib/l10n');
    late Map<String, dynamic> english;
    late List<File> otherLocales;

    setUpAll(() {
      expect(
        arbDir.existsSync(),
        isTrue,
        reason: 'Expected lib/l10n/ to exist relative to the project root',
      );
      final enFile = File('lib/l10n/app_en.arb');
      expect(
        enFile.existsSync(),
        isTrue,
        reason: 'Source locale app_en.arb must exist',
      );
      english = _decodeArb(enFile);
      otherLocales =
          arbDir
              .listSync()
              .whereType<File>()
              .where(
                (file) =>
                    file.path.endsWith('.arb') &&
                    !file.path.endsWith('app_en.arb'),
              )
              .toList();
      expect(
        otherLocales,
        isNotEmpty,
        reason: 'Expected at least one non-English ARB file',
      );
    });

    test('should keep every locale message key in parity with English', () {
      final enKeys = _messageKeys(english);
      for (final file in otherLocales) {
        final localeKeys = _messageKeys(_decodeArb(file));
        final missing = enKeys.difference(localeKeys);
        final extra = localeKeys.difference(enKeys);

        expect(
          missing,
          isEmpty,
          reason:
              '${_basename(file.path)} is missing keys present in app_en.arb: '
              '${missing.join(', ')}',
        );
        expect(
          extra,
          isEmpty,
          reason:
              '${_basename(file.path)} has keys not present in app_en.arb: '
              '${extra.join(', ')}',
        );
      }
    });

    test('should keep placeholder sets in parity with English', () {
      for (final file in otherLocales) {
        final locale = _decodeArb(file);
        for (final key in _messageKeys(english)) {
          final sourceMessage = english[key]! as String;
          final localizedMessage = locale[key]! as String;
          final expected = _placeholderReferences(sourceMessage);
          final actual = _placeholderReferences(localizedMessage);
          expect(
            actual,
            expected,
            reason:
                '${_basename(file.path)} message "$key" must use the same '
                'placeholder set as app_en.arb',
          );
        }
      }
    });

    test('should keep plural categories in parity with English', () {
      for (final key in _messageKeys(english)) {
        final sourceMessage = english[key];
        if (sourceMessage is! String || !sourceMessage.contains(', plural,')) {
          continue;
        }
        final expected = _pluralCategories(sourceMessage);

        for (final file in otherLocales) {
          final locale = _decodeArb(file);
          final localizedMessage = locale[key];
          expect(
            localizedMessage,
            isA<String>(),
            reason: '${_basename(file.path)} message "$key" must be a string',
          );
          expect(
            _pluralCategories(localizedMessage! as String),
            expected,
            reason:
                '${_basename(file.path)} plural "$key" must declare the same '
                'categories as app_en.arb',
          );
        }
      }
    });
  });
}

Map<String, dynamic> _decodeArb(File arb) =>
    json.decode(arb.readAsStringSync()) as Map<String, dynamic>;

/// Returns the set of user-facing message keys in [arb], excluding
/// metadata keys (those starting with `@`) and the top-level
/// `@@locale` / `@@context` markers.
Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

Set<String> _placeholderReferences(String message) =>
    RegExp(
      r'\{([A-Za-z_][A-Za-z0-9_]*)(?:\s*,|\})',
    ).allMatches(message).map((match) => match.group(1)!).toSet();

Set<String> _pluralCategories(String message) =>
    RegExp(
      r'(?:^|\s)(=\d+|zero|one|two|few|many|other)\s*\{',
    ).allMatches(message).map((match) => match.group(1)!).toSet();

String _basename(String path) => path.split(Platform.pathSeparator).last;
