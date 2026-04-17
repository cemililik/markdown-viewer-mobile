import 'package:markdown_viewer/features/settings/domain/app_locale.dart';
import 'package:markdown_viewer/features/settings/domain/app_theme_mode.dart';
import 'package:markdown_viewer/features/settings/domain/reading_settings.dart';
import 'package:markdown_viewer/features/settings/domain/repositories/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences`-backed [SettingsStore] implementation.
///
/// Kept intentionally boring — one key per setting, simple codecs, no
/// serialisation library. Each method is synchronous against the
/// already-loaded preferences instance so controllers can seed their
/// initial state without awaiting I/O.
class SettingsStoreImpl implements SettingsStore {
  SettingsStoreImpl(this._prefs);

  final SharedPreferences _prefs;

  static const String _themeModeKey = 'settings.themeMode';
  static const String _localeTagKey = 'settings.localeTag';
  static const String _bookmarkHintSeenKey = 'settings.bookmarkHintSeen';
  static const String _readingFontScaleKey = 'settings.readingFontScale';
  static const String _readingWidthKey = 'settings.readingWidth';
  static const String _readingLineHeightKey = 'settings.readingLineHeight';
  static const String _keepScreenOnKey = 'settings.keepScreenOn';

  @override
  AppThemeMode readAppThemeMode() {
    return AppThemeMode.fromTag(_prefs.getString(_themeModeKey));
  }

  @override
  Future<void> writeAppThemeMode(AppThemeMode mode) {
    return _prefs.setString(_themeModeKey, mode.tag);
  }

  @override
  AppLocale readLocale() => AppLocale.fromTag(_prefs.getString(_localeTagKey));

  @override
  Future<void> writeLocale(AppLocale locale) {
    return _prefs.setString(_localeTagKey, locale.tag);
  }

  @override
  bool readHasSeenBookmarkHint() {
    return _prefs.getBool(_bookmarkHintSeenKey) ?? false;
  }

  @override
  Future<void> markBookmarkHintSeen() {
    return _prefs.setBool(_bookmarkHintSeenKey, true);
  }

  @override
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

  @override
  Future<void> writeReadingSettings(ReadingSettings settings) async {
    final clampedScale = settings.fontScale.clamp(
      ReadingSettings.minFontScale,
      ReadingSettings.maxFontScale,
    );
    await _prefs.setDouble(_readingFontScaleKey, clampedScale);
    await _prefs.setString(_readingWidthKey, settings.width.tag);
    await _prefs.setString(_readingLineHeightKey, settings.lineHeight.tag);
  }

  @override
  bool readKeepScreenOn() {
    return _prefs.getBool(_keepScreenOnKey) ?? false;
  }

  @override
  Future<void> writeKeepScreenOn(bool value) {
    return _prefs.setBool(_keepScreenOnKey, value);
  }
}
