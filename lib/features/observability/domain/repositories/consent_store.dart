/// Persistence port for user-consent flags that gate observability
/// features (currently: crash reporting).
///
/// The application layer binds to this abstract interface so
/// `CrashReportingController` can be overridden with a fake in tests
/// and so the composition root is the only place in the tree that
/// touches the concrete `SharedPreferences`-backed implementation.
///
/// Reads are synchronous — the data-layer implementation is seeded
/// from an already-loaded `SharedPreferences` instance so `main.dart`
/// can evaluate consent before `runApp`. Writes return a `Future`
/// the caller is expected to `await` so persistence failures
/// propagate to the UI layer.
abstract interface class ConsentStore {
  /// Returns `true` when the user has explicitly opted in to sending
  /// anonymous crash reports. `false` on a fresh install.
  bool readCrashReportingEnabled();

  /// Persists the user's crash-reporting preference. Throws if the
  /// underlying `SharedPreferences.setBool` returns `false` so the
  /// settings screen can surface the failure in a snackbar instead
  /// of silently leaving the in-memory state diverged from disk.
  Future<void> writeCrashReportingEnabled(bool enabled);
}
