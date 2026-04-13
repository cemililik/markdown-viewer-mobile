import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
import 'package:markdown_viewer/features/settings/data/settings_store.dart';
import 'package:markdown_viewer/features/settings/domain/app_locale.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unit tests for [ThemeModeController] and [LocaleController]. Both
/// controllers share the same "seed from store, mutate in memory,
/// fire-and-forget persistence" shape, so one test file covers both.
///
/// The tests run against a real [SettingsStore] backed by the in-memory
/// `SharedPreferences.setMockInitialValues`. That lets us verify both
/// the initial-seed path and the persistence side-effect without
/// mocking the store itself — there is no behaviour in the store
/// worth mocking.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<ProviderContainer> buildContainer() async {
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore(prefs);
    final container = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ThemeModeController', () {
    test('seeds its initial value from the settings store', () async {
      SharedPreferences.setMockInitialValues({'settings.themeMode': 'dark'});
      final container = await buildContainer();

      expect(container.read(themeModeControllerProvider), ThemeMode.dark);
    });

    test(
      'defaults to ThemeMode.system when no value has been persisted',
      () async {
        final container = await buildContainer();

        expect(container.read(themeModeControllerProvider), ThemeMode.system);
      },
    );

    test('set updates in-memory state synchronously', () async {
      final container = await buildContainer();
      final notifier = container.read(themeModeControllerProvider.notifier);

      notifier.set(ThemeMode.light);

      expect(container.read(themeModeControllerProvider), ThemeMode.light);
    });

    test('set persists the value through the underlying store', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsStore(prefs);
      final container = ProviderContainer(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      container.read(themeModeControllerProvider.notifier).set(ThemeMode.dark);

      // Give the fire-and-forget write a microtask to land.
      await Future<void>.delayed(Duration.zero);
      expect(store.readThemeMode(), ThemeMode.dark);
    });

    test('set is a no-op when the value is unchanged', () async {
      final container = await buildContainer();
      final notifier = container.read(themeModeControllerProvider.notifier);
      final before = container.read(themeModeControllerProvider);

      notifier.set(before);

      expect(container.read(themeModeControllerProvider), before);
    });
  });

  group('LocaleController', () {
    test('seeds its initial value from the settings store', () async {
      SharedPreferences.setMockInitialValues({'settings.localeTag': 'tr'});
      final container = await buildContainer();

      expect(container.read(localeControllerProvider), AppLocale.turkish);
    });

    test(
      'defaults to AppLocale.system when no value has been persisted',
      () async {
        final container = await buildContainer();

        expect(container.read(localeControllerProvider), AppLocale.system);
      },
    );

    test('set updates in-memory state and persists', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SettingsStore(prefs);
      final container = ProviderContainer(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      container.read(localeControllerProvider.notifier).set(AppLocale.english);

      expect(container.read(localeControllerProvider), AppLocale.english);
      await Future<void>.delayed(Duration.zero);
      expect(store.readLocale(), AppLocale.english);
    });
  });
}
