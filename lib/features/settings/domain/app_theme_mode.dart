/// The four theme options the user can choose from. Extends Flutter's
/// built-in three-value [ThemeMode] with a "Sepia" option that forces
/// a warm-parchment colour scheme regardless of the OS dark/light
/// preference.
enum AppThemeMode {
  /// Follow the operating-system light/dark preference.
  system,

  /// Force the app-wide light colour scheme.
  light,

  /// Force the app-wide dark colour scheme.
  dark,

  /// Force a warm sepia colour scheme derived from paper/ink tones.
  /// Internally maps to [ThemeMode.light] with a custom [ThemeData].
  sepia;

  /// Stable string tag used by [SettingsStore] for persistence.
  /// Matches the pre-existing tags used for the first three values so
  /// an upgrade from a build that stored `'light'` or `'dark'` is
  /// transparent — [fromTag] will decode both old and new values.
  String get tag {
    switch (this) {
      case AppThemeMode.system:
        return 'system';
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
      case AppThemeMode.sepia:
        return 'sepia';
    }
  }

  /// Decodes a persisted [tag] string back to [AppThemeMode].
  /// Unknown tags (including tags written by a future app version)
  /// fall back to [AppThemeMode.system] so the app never gets stuck
  /// in an unrecognised state.
  static AppThemeMode fromTag(String? tag) {
    switch (tag) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'sepia':
        return AppThemeMode.sepia;
      case 'system':
      default:
        return AppThemeMode.system;
    }
  }
}
