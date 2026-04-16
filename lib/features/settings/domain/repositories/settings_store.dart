import 'package:markdown_viewer/features/settings/domain/app_locale.dart';
import 'package:markdown_viewer/features/settings/domain/app_theme_mode.dart';
import 'package:markdown_viewer/features/settings/domain/reading_settings.dart';

/// Persistence port for all user settings.
///
/// The domain layer declares the read/write surface the rest of the
/// app consumes so no application-layer provider needs to reach into
/// `data/`. The concrete implementation lives under
/// `data/settings_store_impl.dart` and is wired through the
/// composition root in `lib/main.dart`.
///
/// Reads are synchronous — the data-layer implementation is seeded
/// from an already-loaded `SharedPreferences` instance so controllers
/// can compute their initial state without awaiting I/O. Writes
/// return a `Future` the caller can `ignore()` or `await`.
abstract interface class SettingsStore {
  /// Returns the persisted [AppThemeMode] or [AppThemeMode.system] when
  /// nothing has been stored yet.
  AppThemeMode readAppThemeMode();

  /// Persists [mode].
  Future<void> writeAppThemeMode(AppThemeMode mode);

  /// Returns the persisted [AppLocale] or [AppLocale.system] when
  /// nothing has been stored yet.
  AppLocale readLocale();

  /// Persists [locale].
  Future<void> writeLocale(AppLocale locale);

  /// Returns whether the bookmark hint has been seen.
  bool readHasSeenBookmarkHint();

  /// Marks the bookmark hint as seen.
  Future<void> markBookmarkHintSeen();

  /// Returns the persisted [ReadingSettings], or
  /// [ReadingSettings.defaults] for any field that has not been
  /// written yet.
  ReadingSettings readReadingSettings();

  /// Persists [settings].
  Future<void> writeReadingSettings(ReadingSettings settings);

  /// Returns whether the screen should stay on while the viewer is
  /// open. Defaults to `false`.
  bool readKeepScreenOn();

  /// Persists the keep-screen-on preference.
  Future<void> writeKeepScreenOn(bool value);
}
