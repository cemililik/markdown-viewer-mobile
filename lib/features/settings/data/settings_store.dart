import 'package:markdown_viewer/features/settings/domain/app_locale.dart';
import 'package:markdown_viewer/features/settings/domain/app_theme_mode.dart';
import 'package:markdown_viewer/features/settings/domain/reading_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin `SharedPreferences` wrapper that persists all user settings.
///
/// Kept intentionally boring — one key per setting, simple codecs, no
/// serialisation library. Each method is synchronous against the
/// already-loaded preferences instance so controllers can seed their
/// initial state without awaiting I/O.
class SettingsStore {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _themeModeKey = 'settings.themeMode';
  static const String _localeTagKey = 'settings.localeTag';
  static const String _bookmarkHintSeenKey = 'settings.bookmarkHintSeen';
  static const String _readingFontScaleKey = 'settings.readingFontScale';
  static const String _readingWidthKey = 'settings.readingWidth';
  static const String _readingLineHeightKey = 'settings.readingLineHeight';
  static const String _keepScreenOnKey = 'settings.keepScreenOn';

  /// Returns the persisted [AppThemeMode] or [AppThemeMode.system] when
  /// nothing has been stored yet. The prefs key and tag strings are
  /// intentionally identical to the legacy `ThemeMode` tags (`'light'`,
  /// `'dark'`, `'system'`) so existing prefs survive the migration.
  AppThemeMode readAppThemeMode() {
    return AppThemeMode.fromTag(_prefs.getString(_themeModeKey));
  }

  /// Persists [mode] using stable tag strings. Returns the underlying
  /// [Future] so callers can `ignore()` it or await it.
  Future<void> writeAppThemeMode(AppThemeMode mode) {
    return _prefs.setString(_themeModeKey, mode.tag);
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

  /// Returns whether the bookmark hint has been seen.
  bool readHasSeenBookmarkHint() {
    return _prefs.getBool(_bookmarkHintSeenKey) ?? false;
  }

  /// Marks the bookmark hint as seen.
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

  /// Returns whether the screen should stay on while the viewer is
  /// open. Defaults to `false` so a fresh install matches the OS
  /// default of allowing the screen to sleep.
  bool readKeepScreenOn() {
    return _prefs.getBool(_keepScreenOnKey) ?? false;
  }

  /// Persists the keep-screen-on preference.
  Future<void> writeKeepScreenOn(bool value) {
    return _prefs.setBool(_keepScreenOnKey, value);
  }
}
