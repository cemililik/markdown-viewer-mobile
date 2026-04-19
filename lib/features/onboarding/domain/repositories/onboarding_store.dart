/// Port for the onboarding completion store.
///
/// Reads are synchronous so the router's redirect guard can consult
/// the seen-version without awaiting I/O; writes return a `Future`
/// so callers can choose to drop or observe completion.
///
/// ## Version model
///
/// Only a single integer is stored: the onboarding content version
/// the user most recently finished or skipped. The current content
/// version is declared in the application layer
/// (`currentOnboardingVersion`) and bumped manually whenever the
/// steps list changes in a way that warrants a re-show. The router
/// compares the two on every cold start and routes through
/// onboarding when the stored value lags behind — so a fresh install
/// (stored == 0) and a post-update user (stored < current) are
/// handled by the exact same code path.
abstract class OnboardingStore {
  /// Returns the onboarding content version the user most recently
  /// completed, or `0` when nothing has been stored yet (fresh
  /// install). The caller is expected to compare this against the
  /// authoritative `currentOnboardingVersion`.
  int readSeenVersion();

  /// Persists [version] as the highest onboarding content version
  /// the user has acknowledged. Callers pass the current version
  /// constant so a future bump re-triggers the flow automatically.
  Future<void> writeSeenVersion(int version);
}
