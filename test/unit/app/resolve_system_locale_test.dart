import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/app/app.dart';

void main() {
  // The `supportedLocales` argument is ignored by the implementation —
  // it filters the OS list against a hard-coded tr/en whitelist — but
  // the MaterialApp contract still requires us to pass the real list.
  const supported = <Locale>[Locale('en'), Locale('tr')];

  group('resolveSystemLocale', () {
    test('returns Turkish when the OS primary is Turkish', () {
      final resolved = resolveSystemLocale(const [
        Locale('tr', 'TR'),
      ], supported);
      expect(resolved, const Locale('tr'));
    });

    test('returns English when the OS primary is English', () {
      final resolved = resolveSystemLocale(const [
        Locale('en', 'US'),
      ], supported);
      expect(resolved, const Locale('en'));
    });

    test('falls back to English for a completely unsupported OS language', () {
      // German primary, no other preference — the product rule is "anything
      // that is not tr or en falls back to en".
      final resolved = resolveSystemLocale(const [
        Locale('de', 'DE'),
      ], supported);
      expect(resolved, const Locale('en'));
    });

    test('honours a later Turkish entry when the primary is unsupported', () {
      // A German expat who speaks Turkish has the OS list [de, tr, en].
      // We should land on Turkish — the first of their preferences we can
      // actually render — not jump straight to the English fallback.
      final resolved = resolveSystemLocale(const [
        Locale('de', 'DE'),
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ], supported);
      expect(resolved, const Locale('tr'));
    });

    test('honours a later English entry when the primary is unsupported and tr '
        'is not present at all', () {
      final resolved = resolveSystemLocale(const [
        Locale('ja', 'JP'),
        Locale('en', 'GB'),
      ], supported);
      expect(resolved, const Locale('en'));
    });

    test('returns English when the OS preferred list is empty', () {
      final resolved = resolveSystemLocale(const <Locale>[], supported);
      expect(resolved, const Locale('en'));
    });

    test('returns English when the OS preferred list is null', () {
      final resolved = resolveSystemLocale(null, supported);
      expect(resolved, const Locale('en'));
    });

    test('matches on languageCode ignoring country and script', () {
      // A regional variant like zh_Hant_HK should not be interpreted as
      // English or Turkish — it's simply unsupported and falls back.
      final resolved = resolveSystemLocale(const [
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ], supported);
      expect(resolved, const Locale('en'));
    });
  });
}
