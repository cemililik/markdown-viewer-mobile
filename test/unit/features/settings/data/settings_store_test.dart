import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/settings/data/settings_store_impl.dart';
import 'package:markdown_viewer/features/settings/domain/app_locale.dart';
import 'package:markdown_viewer/features/settings/domain/app_theme_mode.dart';
import 'package:markdown_viewer/features/settings/domain/reading_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsStore', () {
    setUp(() {
      // Every test starts from an empty `SharedPreferences` map so
      // the "first launch" path (unwritten keys → system defaults)
      // is tested under the same conditions as the write path.
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test(
      'should confirm that readAppThemeMode returns AppThemeMode.system on a fresh install when the behavior is exercised',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SettingsStoreImpl(prefs);

        expect(store.readAppThemeMode(), AppThemeMode.system);
      },
    );

    test(
      'should confirm that writeAppThemeMode persists the value so a subsequent read returns it when the behavior is exercised',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SettingsStoreImpl(prefs);

        await store.writeAppThemeMode(AppThemeMode.dark);

        final reopened = SettingsStoreImpl(prefs);
        expect(reopened.readAppThemeMode(), AppThemeMode.dark);
      },
    );

    test(
      'should confirm that writeAppThemeMode round-trips every AppThemeMode value when the behavior is exercised',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SettingsStoreImpl(prefs);

        for (final mode in AppThemeMode.values) {
          await store.writeAppThemeMode(mode);
          expect(
            store.readAppThemeMode(),
            mode,
            reason: 'round trip for $mode',
          );
        }
      },
    );

    test(
      'should confirm that readAppThemeMode decodes legacy ThemeMode tags without migration when the behavior is exercised',
      () async {
        // A prefs value written by an older build that used Flutter's
        // ThemeMode tag strings must decode transparently.
        for (final entry
            in {
              'light': AppThemeMode.light,
              'dark': AppThemeMode.dark,
              'system': AppThemeMode.system,
            }.entries) {
          SharedPreferences.setMockInitialValues({
            'settings.themeMode': entry.key,
          });
          final prefs = await SharedPreferences.getInstance();
          final store = SettingsStoreImpl(prefs);
          expect(
            store.readAppThemeMode(),
            entry.value,
            reason: 'legacy tag "${entry.key}"',
          );
        }
      },
    );

    test(
      'should confirm that readAppThemeMode returns AppThemeMode.system when the stored tag is '
      'unrecognised',
      () async {
        SharedPreferences.setMockInitialValues({
          'settings.themeMode': 'ultraviolet',
        });
        final prefs = await SharedPreferences.getInstance();
        final store = SettingsStoreImpl(prefs);

        expect(store.readAppThemeMode(), AppThemeMode.system);
      },
    );

    test(
      'should confirm that readLocale returns AppLocale.system on a fresh install when the behavior is exercised',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SettingsStoreImpl(prefs);

        expect(store.readLocale(), AppLocale.system);
      },
    );

    test(
      'should confirm that writeLocale round-trips every AppLocale value when the behavior is exercised',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SettingsStoreImpl(prefs);

        for (final locale in AppLocale.values) {
          await store.writeLocale(locale);
          final reopened = SettingsStoreImpl(prefs);
          expect(reopened.readLocale(), locale);
        }
      },
    );

    test(
      'should confirm that readLocale returns AppLocale.system when the stored tag is '
      'unrecognised',
      () async {
        SharedPreferences.setMockInitialValues({
          'settings.localeTag': 'klingon',
        });
        final prefs = await SharedPreferences.getInstance();
        final store = SettingsStoreImpl(prefs);

        expect(store.readLocale(), AppLocale.system);
      },
    );

    test(
      'should confirm that readHasSeenBookmarkHint defaults to false on a fresh install when the behavior is exercised',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SettingsStoreImpl(prefs);

        expect(store.readHasSeenBookmarkHint(), isFalse);
      },
    );

    test(
      'should confirm that markBookmarkHintSeen persists and makes the flag read back as true when the behavior is exercised',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SettingsStoreImpl(prefs);

        expect(store.readHasSeenBookmarkHint(), isFalse);
        await store.markBookmarkHintSeen();
        final reopened = SettingsStoreImpl(prefs);
        expect(reopened.readHasSeenBookmarkHint(), isTrue);
      },
    );

    test(
      'should confirm that readReadingSettings returns the defaults on a fresh install when the behavior is exercised',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SettingsStoreImpl(prefs);

        final read = store.readReadingSettings();
        expect(read.fontScale, ReadingSettings.defaults.fontScale);
        expect(read.width, ReadingSettings.defaults.width);
        expect(read.lineHeight, ReadingSettings.defaults.lineHeight);
      },
    );

    test(
      'should confirm that writeReadingSettings round-trips the three knobs together when the behavior is exercised',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SettingsStoreImpl(prefs);

        await store.writeReadingSettings(
          const ReadingSettings(
            fontScale: 1.15,
            width: ReadingWidth.wide,
            lineHeight: ReadingLineHeight.airy,
          ),
        );
        final reopened = SettingsStoreImpl(prefs);
        final read = reopened.readReadingSettings();

        expect(read.fontScale, closeTo(1.15, 1e-9));
        expect(read.width, ReadingWidth.wide);
        expect(read.lineHeight, ReadingLineHeight.airy);
      },
    );

    test(
      'should confirm that writeReadingSettings clamps an out-of-range font scale to the '
      'supported window when the behavior is exercised',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SettingsStoreImpl(prefs);

        await store.writeReadingSettings(
          const ReadingSettings(
            fontScale: 3.0,
            width: ReadingWidth.comfortable,
            lineHeight: ReadingLineHeight.standard,
          ),
        );
        final read = store.readReadingSettings();

        expect(read.fontScale, ReadingSettings.maxFontScale);
      },
    );

    test(
      'should confirm that readKeepScreenOn defaults to false on a fresh install when the behavior is exercised',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SettingsStoreImpl(prefs);

        expect(store.readKeepScreenOn(), isFalse);
      },
    );

    test(
      'should confirm that writeKeepScreenOn persists and round-trips the value when the behavior is exercised',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final store = SettingsStoreImpl(prefs);

        await store.writeKeepScreenOn(true);
        final reopened = SettingsStoreImpl(prefs);
        expect(reopened.readKeepScreenOn(), isTrue);

        await store.writeKeepScreenOn(false);
        final reopened2 = SettingsStoreImpl(prefs);
        expect(reopened2.readKeepScreenOn(), isFalse);
      },
    );
  });
}
