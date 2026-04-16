import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the key-set parity invariant between every ARB locale file
/// and the source-of-truth English file. A missing key on a
/// non-source locale falls through to the English string at runtime,
/// which is both jarring for users and silently lossy — adding a
/// translation and forgetting to wire the key would never surface
/// without this check.
///
/// The pre-commit hook performs the same check to catch mistakes at
/// commit time; this test guarantees the check also runs in CI, per
/// `docs/standards/localization-standards.md`.
void main() {
  group('locale completeness', () {
    final arbDir = Directory('lib/l10n');

    test('every non-source ARB has the same key set as app_en.arb', () {
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

      final enKeys = _messageKeys(enFile);

      final otherLocales =
          arbDir
              .listSync()
              .whereType<File>()
              .where(
                (f) =>
                    f.path.endsWith('.arb') && !f.path.endsWith('app_en.arb'),
              )
              .toList();

      expect(
        otherLocales,
        isNotEmpty,
        reason: 'Expected at least one non-English ARB file',
      );

      for (final file in otherLocales) {
        final localeKeys = _messageKeys(file);
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
  });
}

/// Returns the set of user-facing message keys in [arb], excluding
/// metadata keys (those starting with `@`) and the top-level
/// `@@locale` / `@@context` markers.
Set<String> _messageKeys(File arb) {
  final decoded = json.decode(arb.readAsStringSync()) as Map<String, dynamic>;
  return decoded.keys.where((k) => !k.startsWith('@')).toSet();
}

String _basename(String path) => path.split(Platform.pathSeparator).last;
