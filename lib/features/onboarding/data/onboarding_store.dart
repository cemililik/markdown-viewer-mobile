import 'package:shared_preferences/shared_preferences.dart';

/// Thin `SharedPreferences` wrapper that persists the onboarding
/// completion state.
///
/// Mirrors the [SettingsStore] pattern: reads are synchronous against
/// the already-loaded preferences instance (so the router's redirect
/// guard can consult it without awaiting I/O), and writes return a
/// `Future` the caller can `ignore()` or `await`.
///
/// ## Version model
///
/// Only a single integer is stored: the onboarding content version
/// the user most recently finished or skipped. The current content
/// version is declared in the application layer (`currentOnboardingVersion`)
/// and bumped manually whenever the steps list changes in a way that
/// warrants a re-show. The router compares the two on every cold
/// start and routes through onboarding when the stored value lags
/// behind — so a fresh install (stored == 0) and a post-update user
/// (stored < current) are handled by the exact same code path.
class OnboardingStore {
  OnboardingStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _seenVersionKey = 'onboarding.seenVersion';

  /// Returns the onboarding content version the user most recently
  /// completed, or `0` when nothing has been stored yet (fresh
  /// install). The caller is expected to compare this against the
  /// authoritative `currentOnboardingVersion` declared in
  /// `onboarding_providers.dart`.
  int readSeenVersion() {
    return _prefs.getInt(_seenVersionKey) ?? 0;
  }

  /// Persists [version] as the highest onboarding content version
  /// the user has acknowledged. Callers pass the current version
  /// constant so a future bump re-triggers the flow automatically.
  Future<void> writeSeenVersion(int version) {
    return _prefs.setInt(_seenVersionKey, version);
  }
}
