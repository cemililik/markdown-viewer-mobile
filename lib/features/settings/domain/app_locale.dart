import 'dart:ui' show Locale;

/// Domain-layer enum describing every locale the user can pick from
/// the settings screen, plus the "follow the operating system"
/// option. Kept in the domain layer so the application and
/// presentation layers depend on an abstraction that never leaks
/// `SharedPreferences`-specific encoding concerns.
///
/// The [Locale] value is deliberately nullable for [AppLocale.system]
/// — `MaterialApp.locale: null` is how Flutter is told to follow the
/// `Localizations` delegate resolution against the OS language list.
enum AppLocale {
  system(null, 'system'),
  english(Locale('en'), 'en'),
  turkish(Locale('tr'), 'tr');

  const AppLocale(this.locale, this.tag);

  /// The [Locale] to hand to `MaterialApp.locale`. `null` for
  /// [AppLocale.system], which means "use OS resolution".
  final Locale? locale;

  /// Stable short identifier persisted in `SharedPreferences`. Three
  /// fixed values so future changes can be migrated explicitly.
  final String tag;

  /// Reverse lookup used when hydrating state from persistence.
  /// Returns [AppLocale.system] for an unknown / missing tag so a
  /// fresh install always starts following the OS language.
  static AppLocale fromTag(String? tag) {
    if (tag == null) {
      return AppLocale.system;
    }
    for (final value in AppLocale.values) {
      if (value.tag == tag) {
        return value;
      }
    }
    return AppLocale.system;
  }
}
