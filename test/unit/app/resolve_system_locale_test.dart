import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/app/app.dart';
import 'package:markdown_viewer/features/settings/domain/app_locale.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

void main() {
  const supported = AppLocalizations.supportedLocales;

  group('resolveSystemLocale', () {
    test('should returns Turkish when the OS primary is Turkish', () {
      final resolved = resolveSystemLocale(const [
        Locale('tr', 'TR'),
      ], supported);
      expect(resolved, const Locale('tr'));
    });

    test('should returns English when the OS primary is English', () {
      final resolved = resolveSystemLocale(const [
        Locale('en', 'US'),
      ], supported);
      expect(resolved, const Locale('en'));
    });

    test(
      'should falls back to English for a completely unsupported OS language',
      () {
        // German primary, no other preference — the product rule is "anything
        // that is not tr or en falls back to en".
        final resolved = resolveSystemLocale(const [
          Locale('de', 'DE'),
        ], supported);
        expect(resolved, const Locale('en'));
      },
    );

    test(
      'should honours a later Turkish entry when the primary is unsupported',
      () {
        // A German expat who speaks Turkish has the OS list [de, tr, en].
        // We should land on Turkish — the first of their preferences we can
        // actually render — not jump straight to the English fallback.
        final resolved = resolveSystemLocale(const [
          Locale('de', 'DE'),
          Locale('tr', 'TR'),
          Locale('en', 'US'),
        ], supported);
        expect(resolved, const Locale('tr'));
      },
    );

    test(
      'should honours a later English entry when the primary is unsupported and tr '
      'is not present at all',
      () {
        final resolved = resolveSystemLocale(const [
          Locale('ja', 'JP'),
          Locale('en', 'GB'),
        ], supported);
        expect(resolved, const Locale('en'));
      },
    );

    test('should returns English when the OS preferred list is empty', () {
      final resolved = resolveSystemLocale(const <Locale>[], supported);
      expect(resolved, const Locale('en'));
    });

    test('should returns English when the OS preferred list is null', () {
      final resolved = resolveSystemLocale(null, supported);
      expect(resolved, const Locale('en'));
    });

    test('should matches on languageCode ignoring country and script', () {
      // A regional variant like zh_Hant_HK should not be interpreted as
      // English or Turkish — it's simply unsupported and falls back.
      final resolved = resolveSystemLocale(const [
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ], supported);
      expect(resolved, const Locale('en'));
    });

    test(
      'should derive selectable locales from generated supported locales',
      () {
        final generatedLanguageCodes =
            AppLocalizations.supportedLocales
                .map((locale) => locale.languageCode)
                .toSet();
        final selectableLanguageCodes =
            AppLocale.values
                .map((locale) => locale.locale)
                .whereType<Locale>()
                .map((locale) => locale.languageCode)
                .toSet();

        expect(selectableLanguageCodes, generatedLanguageCodes);
      },
    );

    test('should resolve a future supported locale without code changes', () {
      const futureSupported = <Locale>[
        Locale('en'),
        Locale('tr'),
        Locale('de'),
      ];

      final resolved = resolveSystemLocale(const [
        Locale('ja', 'JP'),
        Locale('de', 'DE'),
      ], futureSupported);

      expect(resolved, const Locale('de'));
    });
  });
}
