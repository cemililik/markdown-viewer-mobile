import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/domain/app_locale.dart';
import 'package:markdown_viewer/features/settings/domain/app_theme_mode.dart';
import 'package:markdown_viewer/features/settings/domain/reading_settings.dart';
import 'package:markdown_viewer/features/settings/domain/repositories/settings_store.dart';

void main() {
  late _RecordingSettingsStore store;

  setUp(() {
    store = _RecordingSettingsStore();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ThemeModeController', () {
    test(
      'should seed its initial value from the settings store when the behavior is exercised',
      () {
        store.themeMode = AppThemeMode.dark;

        final container = buildContainer();

        expect(container.read(themeModeControllerProvider), AppThemeMode.dark);
      },
    );

    test('should default to system theme when no value is persisted', () {
      final container = buildContainer();

      expect(container.read(themeModeControllerProvider), AppThemeMode.system);
    });

    test(
      'should update state and persist a changed theme when the behavior is exercised',
      () {
        final container = buildContainer();

        container
            .read(themeModeControllerProvider.notifier)
            .set(AppThemeMode.sepia);

        expect(container.read(themeModeControllerProvider), AppThemeMode.sepia);
        expect(store.themeMode, AppThemeMode.sepia);
        expect(store.themeWrites, 1);
      },
    );

    test('should skip persistence when the theme is unchanged', () {
      final container = buildContainer();

      container
          .read(themeModeControllerProvider.notifier)
          .set(AppThemeMode.system);

      expect(store.themeWrites, 0);
    });
  });

  group('LocaleController', () {
    test(
      'should seed its initial value from the settings store when the behavior is exercised',
      () {
        store.locale = AppLocale.turkish;

        final container = buildContainer();

        expect(container.read(localeControllerProvider), AppLocale.turkish);
      },
    );

    test('should default to system locale when no value is persisted', () {
      final container = buildContainer();

      expect(container.read(localeControllerProvider), AppLocale.system);
    });

    test(
      'should update state and persist a changed locale when the behavior is exercised',
      () {
        final container = buildContainer();

        container
            .read(localeControllerProvider.notifier)
            .set(AppLocale.english);

        expect(container.read(localeControllerProvider), AppLocale.english);
        expect(store.locale, AppLocale.english);
        expect(store.localeWrites, 1);
      },
    );

    test('should skip persistence when the locale is unchanged', () {
      final container = buildContainer();

      container.read(localeControllerProvider.notifier).set(AppLocale.system);

      expect(store.localeWrites, 0);
    });
  });

  group('ReadingSettingsController', () {
    test(
      'should seed initial state from the store when the behavior is exercised',
      () {
        store.readingSettings = const ReadingSettings(
          fontScale: 1.2,
          width: ReadingWidth.wide,
          lineHeight: ReadingLineHeight.airy,
        );

        final container = buildContainer();

        expect(
          container.read(readingSettingsControllerProvider),
          store.readingSettings,
        );
      },
    );

    test(
      'should update state and persist a changed font scale when the behavior is exercised',
      () {
        final container = buildContainer();

        container
            .read(readingSettingsControllerProvider.notifier)
            .setFontScale(1.2);

        expect(
          container.read(readingSettingsControllerProvider).fontScale,
          closeTo(1.2, 1e-9),
        );
        expect(store.readingSettings.fontScale, closeTo(1.2, 1e-9));
        expect(store.readingWrites, 1);
      },
    );

    test(
      'should clamp font scale before persisting it when the behavior is exercised',
      () {
        final container = buildContainer();
        final controller = container.read(
          readingSettingsControllerProvider.notifier,
        );

        controller.setFontScale(5);
        expect(store.readingSettings.fontScale, ReadingSettings.maxFontScale);

        controller.setFontScale(0.1);
        expect(store.readingSettings.fontScale, ReadingSettings.minFontScale);
        expect(store.readingWrites, 2);
      },
    );

    test(
      'should update width and line height independently when the behavior is exercised',
      () {
        final container = buildContainer();
        final controller = container.read(
          readingSettingsControllerProvider.notifier,
        );

        controller
          ..setWidth(ReadingWidth.wide)
          ..setLineHeight(ReadingLineHeight.airy);

        final state = container.read(readingSettingsControllerProvider);
        expect(state.width, ReadingWidth.wide);
        expect(state.lineHeight, ReadingLineHeight.airy);
        expect(state.fontScale, ReadingSettings.defaults.fontScale);
        expect(store.readingWrites, 2);
      },
    );

    test(
      'should restore and persist every reading default when the behavior is exercised',
      () {
        store.readingSettings = const ReadingSettings(
          fontScale: 1.4,
          width: ReadingWidth.wide,
          lineHeight: ReadingLineHeight.airy,
        );
        final container = buildContainer();

        container
            .read(readingSettingsControllerProvider.notifier)
            .resetToDefaults();

        expect(
          container.read(readingSettingsControllerProvider),
          ReadingSettings.defaults,
        );
        expect(store.readingSettings, ReadingSettings.defaults);
        expect(store.readingWrites, 1);
      },
    );

    test('should skip persistence when reading settings are unchanged', () {
      final container = buildContainer();
      final controller = container.read(
        readingSettingsControllerProvider.notifier,
      );

      controller
        ..setFontScale(ReadingSettings.defaults.fontScale)
        ..setWidth(ReadingSettings.defaults.width)
        ..setLineHeight(ReadingSettings.defaults.lineHeight)
        ..resetToDefaults();

      expect(store.readingWrites, 0);
    });
  });

  group('KeepScreenOnController', () {
    test(
      'should seed its initial value from the settings store when the behavior is exercised',
      () {
        store.keepScreenOn = true;

        final container = buildContainer();

        expect(container.read(keepScreenOnControllerProvider), isTrue);
      },
    );

    test(
      'should update state and persist a changed value when the behavior is exercised',
      () {
        final container = buildContainer();

        container.read(keepScreenOnControllerProvider.notifier).set(true);

        expect(container.read(keepScreenOnControllerProvider), isTrue);
        expect(store.keepScreenOn, isTrue);
        expect(store.keepScreenOnWrites, 1);
      },
    );

    test('should skip persistence when the value is unchanged', () {
      final container = buildContainer();

      container.read(keepScreenOnControllerProvider.notifier).set(false);

      expect(store.keepScreenOnWrites, 0);
    });
  });
}

final class _RecordingSettingsStore implements SettingsStore {
  AppThemeMode themeMode = AppThemeMode.system;
  AppLocale locale = AppLocale.system;
  ReadingSettings readingSettings = ReadingSettings.defaults;
  bool keepScreenOn = false;
  bool hasSeenBookmarkHint = false;

  int themeWrites = 0;
  int localeWrites = 0;
  int readingWrites = 0;
  int keepScreenOnWrites = 0;

  @override
  AppThemeMode readAppThemeMode() => themeMode;

  @override
  Future<void> writeAppThemeMode(AppThemeMode mode) async {
    themeWrites += 1;
    themeMode = mode;
  }

  @override
  AppLocale readLocale() => locale;

  @override
  Future<void> writeLocale(AppLocale value) async {
    localeWrites += 1;
    locale = value;
  }

  @override
  ReadingSettings readReadingSettings() => readingSettings;

  @override
  Future<void> writeReadingSettings(ReadingSettings value) async {
    readingWrites += 1;
    readingSettings = value;
  }

  @override
  bool readKeepScreenOn() => keepScreenOn;

  @override
  Future<void> writeKeepScreenOn(bool value) async {
    keepScreenOnWrites += 1;
    keepScreenOn = value;
  }

  @override
  bool readHasSeenBookmarkHint() => hasSeenBookmarkHint;

  @override
  Future<void> markBookmarkHintSeen() async {
    hasSeenBookmarkHint = true;
  }
}
