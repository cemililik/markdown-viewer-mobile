import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/observability/data/consent_store.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Build-time Sentry DSN injected via `--dart-define=SENTRY_DSN=...`.
///
/// Empty when no DSN is supplied (local development, CI lint runs).
/// Sentry is fully dormant in that case — no initialisation, no
/// network, no hooks, no performance overhead.
const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

/// Whether Sentry is structurally available in this build.
///
/// `false` when `SENTRY_DSN` was not supplied at build time. Even
/// when `true`, Sentry only activates if the user has also opted in
/// via the Settings toggle ([crashReportingControllerProvider]).
bool get sentryAvailable => sentryDsn.isNotEmpty;

/// Holds the [ConsentStore]. Overridden in `main.dart` with an
/// instance backed by the preloaded `SharedPreferences`.
final consentStoreProvider = Provider<ConsentStore>((ref) {
  throw UnimplementedError(
    'consentStoreProvider must be overridden in main.dart',
  );
});

/// Mutable view of the crash-reporting consent state.
///
/// Seeded synchronously from the store on first read so `main.dart`
/// can evaluate consent before `runApp`. Calls to [setEnabled]
/// update the state immediately and fire-and-forget the disk write.
///
/// When the user flips the toggle:
///
/// - **ON:** Sentry is initialised via `SentryFlutter.init` so
///   subsequent crashes, breadcrumbs, and performance events are
///   captured and transmitted.
/// - **OFF:** `Sentry.close()` is called, tearing down all hooks
///   and stopping all network traffic. Any buffered events are
///   discarded.
class CrashReportingController extends Notifier<bool> {
  @override
  bool build() {
    final store = ref.watch(consentStoreProvider);
    return store.readCrashReportingEnabled();
  }

  /// Enables or disables crash reporting and reflects the change in
  /// the running Sentry instance. The caller does NOT need to
  /// restart the app — Sentry's hot-toggle is handled here.
  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    ref.read(consentStoreProvider).writeCrashReportingEnabled(enabled).ignore();

    if (enabled && sentryAvailable) {
      await _initSentry();
    } else {
      await Sentry.close();
    }
  }

  /// Initialises Sentry with the build-time DSN and a conservative
  /// default configuration. Called from two sites:
  ///
  /// 1. `main.dart` on cold start when consent is already `true`.
  /// 2. `setEnabled(true)` when the user flips the toggle at runtime.
  static Future<void> _initSentry() async {
    if (!sentryAvailable) return;
    await SentryFlutter.init((options) {
      options
        ..dsn = sentryDsn
        // Sample 30% of transactions for performance tracing — keeps
        // the free-tier quota manageable while still giving a
        // representative picture of screen load times, HTTP durations,
        // and mermaid render times.
        ..tracesSampleRate = 0.3
        ..attachScreenshot = false
        ..sendDefaultPii = false
        // Only capture warnings and above — debug/info breadcrumbs
        // are added manually via the logger integration.
        ..diagnosticLevel = SentryLevel.warning;
    });
  }

  /// Called from `main.dart` on cold start BEFORE `runApp`.
  /// Initialises Sentry only if both the DSN is present and the
  /// user has previously opted in.
  static Future<void> initIfConsented(ConsentStore store) async {
    if (!sentryAvailable) return;
    if (!store.readCrashReportingEnabled()) return;
    await _initSentry();
  }
}

final crashReportingControllerProvider =
    NotifierProvider<CrashReportingController, bool>(
      CrashReportingController.new,
    );
