import 'package:markdown_viewer/features/onboarding/domain/repositories/onboarding_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences`-backed implementation of [OnboardingStore].
///
/// Mirrors the [SettingsStore] pattern: reads are synchronous against
/// the already-loaded preferences instance, and writes return the
/// `Future` from the SharedPreferences API unchanged.
class OnboardingStoreImpl implements OnboardingStore {
  OnboardingStoreImpl(this._prefs);

  final SharedPreferences _prefs;

  static const String _seenVersionKey = 'onboarding.seenVersion';

  @override
  int readSeenVersion() {
    return _prefs.getInt(_seenVersionKey) ?? 0;
  }

  @override
  Future<void> writeSeenVersion(int version) {
    return _prefs.setInt(_seenVersionKey, version);
  }
}
