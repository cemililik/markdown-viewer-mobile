import 'package:flutter/material.dart' show ThemeMode;
import 'package:markdown_viewer/features/settings/domain/app_locale.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin `SharedPreferences` wrapper that persists the two settings
/// the user can tweak: theme mode and locale choice.
///
/// Kept intentionally boring — two keys, two codecs, no
/// serialisation library. Each method on the store is synchronous
/// against the already-loaded preferences instance so controllers
/// can seed their initial state without awaiting I/O.
class SettingsStore {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _themeModeKey = 'settings.themeMode';
  static const String _localeTagKey = 'settings.localeTag';

  /// Returns the persisted [ThemeMode] or [ThemeMode.system] when
  /// nothing has been stored yet.
  ThemeMode readThemeMode() {
    final raw = _prefs.getString(_themeModeKey);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      case null:
      default:
        return ThemeMode.system;
    }
  }

  /// Persists [mode] using the short string keys above. Returns the
  /// underlying [Future] so callers can `ignore()` it or await it;
  /// production code uses fire-and-forget.
  Future<void> writeThemeMode(ThemeMode mode) {
    return _prefs.setString(_themeModeKey, _themeModeTag(mode));
  }

  /// Returns the persisted [AppLocale] or [AppLocale.system] when
  /// nothing has been stored yet.
  AppLocale readLocale() => AppLocale.fromTag(_prefs.getString(_localeTagKey));

  /// Persists [locale]. [AppLocale.system] is stored as the literal
  /// `'system'` tag rather than removing the key — it makes a future
  /// migration easier and the key does not suddenly spring back to
  /// "never written" semantics after the user explicitly picked
  /// "follow system".
  Future<void> writeLocale(AppLocale locale) {
    return _prefs.setString(_localeTagKey, locale.tag);
  }

  static String _themeModeTag(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
