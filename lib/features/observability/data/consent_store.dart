import 'package:shared_preferences/shared_preferences.dart';

/// Thin `SharedPreferences` wrapper that persists the crash-reporting
/// consent state.
///
/// Mirrors the [SettingsStore] / [OnboardingStore] pattern: reads are
/// synchronous against the already-loaded preferences instance so the
/// composition root can evaluate consent before `runApp`, and writes
/// return a `Future` the caller can `ignore()` or `await`.
///
/// ## Privacy model (ADR-0014 Phase 2)
///
/// Default is `false` — no crash data leaves the device until the
/// user explicitly enables the toggle in Settings. Sentry
/// initialisation in `main.dart` reads the stored value and only
/// calls `SentryFlutter.init` when both the consent flag is `true`
/// AND a non-empty `SENTRY_DSN` was supplied at build time via
/// `--dart-define`. Either condition being false means Sentry is
/// fully dormant — no network, no hooks, no performance overhead.
class ConsentStore {
  ConsentStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _crashReportingKey = 'observability.crashReporting';

  /// Returns `true` when the user has explicitly opted in to sending
  /// anonymous crash reports. `false` on a fresh install.
  bool readCrashReportingEnabled() {
    return _prefs.getBool(_crashReportingKey) ?? false;
  }

  /// Persists the user's crash-reporting preference. The caller is
  /// expected to also call `Sentry.close()` or re-init Sentry to
  /// reflect the new state at runtime.
  Future<void> writeCrashReportingEnabled(bool enabled) {
    return _prefs.setBool(_crashReportingKey, enabled);
  }
}
