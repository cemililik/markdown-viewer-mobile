import 'package:flutter/material.dart' show ThemeMode;
import 'package:markdown_viewer/features/settings/domain/app_locale.dart';
import 'package:markdown_viewer/features/settings/domain/reading_settings.dart';
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
  static const String _bookmarkHintSeenKey = 'settings.bookmarkHintSeen';
  static const String _readingFontScaleKey = 'settings.readingFontScale';
  static const String _readingWidthKey = 'settings.readingWidth';
  static const String _readingLineHeightKey = 'settings.readingLineHeight';

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

  /// Whether the user has already seen the "long-press to remove"
  /// coach-mark that the viewer shows once the first time they
  /// save a reading-position bookmark. A one-shot UI flag that
  /// lives here rather than in its own store because it is still
  /// a per-user preference and the settings store is already the
  /// `SharedPreferences`-wrapper seam every other flag uses.
  bool readHasSeenBookmarkHint() {
    return _prefs.getBool(_bookmarkHintSeenKey) ?? false;
  }

  /// Marks the bookmark long-press coach-mark as seen so the
  /// viewer stops appending the hint line to every subsequent
  /// save confirmation.
  Future<void> markBookmarkHintSeen() {
    return _prefs.setBool(_bookmarkHintSeenKey, true);
  }

  /// Returns the persisted [ReadingSettings], or
  /// [ReadingSettings.defaults] for any field that has not been
  /// written yet. The three reading knobs are stored as
  /// separate keys (not a single JSON blob) so rolling back a
  /// single slider after a bug does not require clearing the
  /// other two.
  ReadingSettings readReadingSettings() {
    final scaleRaw = _prefs.getDouble(_readingFontScaleKey);
    final widthTag = _prefs.getString(_readingWidthKey);
    final lineHeightTag = _prefs.getString(_readingLineHeightKey);
    final clampedScale = (scaleRaw ?? ReadingSettings.defaults.fontScale).clamp(
      ReadingSettings.minFontScale,
      ReadingSettings.maxFontScale,
    );
    return ReadingSettings(
      fontScale: clampedScale,
      width: ReadingWidth.fromTag(widthTag),
      lineHeight: ReadingLineHeight.fromTag(lineHeightTag),
    );
  }

  /// Persists [settings]. The font scale is clamped to the
  /// `[minFontScale, maxFontScale]` range so an out-of-bounds
  /// value from a future migration or a direct prefs edit
  /// cannot wedge the reading layout at an unreadable size.
  Future<void> writeReadingSettings(ReadingSettings settings) async {
    final clampedScale = settings.fontScale.clamp(
      ReadingSettings.minFontScale,
      ReadingSettings.maxFontScale,
    );
    await _prefs.setDouble(_readingFontScaleKey, clampedScale);
    await _prefs.setString(_readingWidthKey, settings.width.tag);
    await _prefs.setString(_readingLineHeightKey, settings.lineHeight.tag);
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
