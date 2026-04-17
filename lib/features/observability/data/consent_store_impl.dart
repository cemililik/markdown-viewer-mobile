import 'package:markdown_viewer/features/observability/domain/repositories/consent_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences`-backed [ConsentStore].
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
class ConsentStoreImpl implements ConsentStore {
  ConsentStoreImpl(this._prefs);

  final SharedPreferences _prefs;

  static const String _crashReportingKey = 'observability.crashReporting';

  @override
  bool readCrashReportingEnabled() {
    return _prefs.getBool(_crashReportingKey) ?? false;
  }

  @override
  Future<void> writeCrashReportingEnabled(bool enabled) async {
    final success = await _prefs.setBool(_crashReportingKey, enabled);
    if (!success) {
      throw StateError(
        'SharedPreferences.setBool failed for $_crashReportingKey=$enabled',
      );
    }
  }
}
