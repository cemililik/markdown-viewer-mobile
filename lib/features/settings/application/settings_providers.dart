import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/settings/data/settings_store.dart';
import 'package:markdown_viewer/features/settings/domain/app_locale.dart';

/// Application-layer binding for the [SettingsStore] port. Thrown by
/// default so a missing composition-root override (tests that forget
/// to wire a fake, a build that forgets to preload
/// `SharedPreferences`) fails loudly instead of silently persisting
/// nothing.
final settingsStoreProvider = Provider<SettingsStore>((ref) {
  throw UnimplementedError(
    'settingsStoreProvider must be overridden in the composition '
    'root (lib/main.dart) after `SharedPreferences.getInstance()` '
    'completes, or in tests with a fake-backed SettingsStore.',
  );
});

/// Notifier that owns the user's chosen [ThemeMode]. The initial
/// value is seeded from the injected [SettingsStore] on first build
/// so [MaterialApp] renders the correct theme on the very first
/// frame — no flash of wrong theme after launch.
///
/// Mutations go through [set], which updates the in-memory state
/// synchronously and fires a persistence write in the background.
/// The UI does not wait on disk I/O.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final store = ref.watch(settingsStoreProvider);
    return store.readThemeMode();
  }

  void set(ThemeMode mode) {
    if (state == mode) {
      return;
    }
    state = mode;
    // Fire-and-forget: `writeThemeMode` returns a Future we
    // deliberately drop so setting a theme feels instantaneous. A
    // failed write surfaces on the next app launch as the old value
    // — acceptable for a cosmetic preference.
    ref.read(settingsStoreProvider).writeThemeMode(mode).ignore();
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// Notifier that owns the user's chosen [AppLocale]. Mirrors
/// [ThemeModeController]'s shape so the composition root can
/// override them the same way.
class LocaleController extends Notifier<AppLocale> {
  @override
  AppLocale build() {
    final store = ref.watch(settingsStoreProvider);
    return store.readLocale();
  }

  void set(AppLocale locale) {
    if (state == locale) {
      return;
    }
    state = locale;
    ref.read(settingsStoreProvider).writeLocale(locale).ignore();
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, AppLocale>(
  LocaleController.new,
);
