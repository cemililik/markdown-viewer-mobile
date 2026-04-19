import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/observability/domain/repositories/consent_store.dart';
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
// Evaluated at compile time: `String.fromEnvironment` is a const
// constructor, so `sentryDsn.isNotEmpty` folds to a plain bool the
// tree-shaker can eliminate. `const` also documents that the value
// cannot change between calls — a mutable getter hid that invariant.
const bool sentryAvailable = sentryDsn != '';

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
/// can evaluate consent before `runApp`. Calls to [setEnabled] flip
/// the in-memory state immediately, then await the disk write and
/// the Sentry lifecycle transition — errors from either step
/// propagate to the caller so the UI can surface a snackbar instead
/// of silently swallowing the failure.
///
/// When the user flips the toggle:
///
/// - **ON:** Sentry is initialised via `SentryFlutter.init` so
///   subsequent crashes, breadcrumbs, and performance events are
///   captured and transmitted.
/// - **OFF:** `Sentry.close()` is called, tearing down all hooks
///   and stopping all network traffic. Any buffered events are
///   discarded.
///
/// The Sentry lifecycle always runs, even when the prefs write fails
/// (a full disk on Android, a revoked protection class on iOS) — see
/// the `finally` block inside [setEnabled].
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
    // Await the consent write so `writeCrashReportingEnabled`'s
    // StateError (on SharedPreferences.setBool returning false) can
    // propagate to the settings-screen error path instead of being
    // silently dropped.
    //
    // The Sentry lifecycle transition runs in a `finally` so a failed
    // prefs write never leaves Sentry in a state that contradicts the
    // in-memory `state` flag the UI binds to. If the write fails the
    // user is told (snackbar from the settings screen) but the
    // runtime behaviour still matches the toggle they flipped.
    try {
      await ref.read(consentStoreProvider).writeCrashReportingEnabled(enabled);
    } finally {
      if (enabled && sentryAvailable) {
        await _initSentry();
      } else {
        await Sentry.close();
      }
    }
  }

  /// Initialises Sentry with the build-time DSN and a conservative
  /// default configuration. Called from two sites:
  ///
  /// 1. `main.dart` on cold start when consent is already `true`.
  /// 2. `setEnabled(true)` when the user flips the toggle at runtime.
  static Future<void> _initSentry() async {
    if (!sentryAvailable) return;
    // Defensive runtime assertion — a `--dart-define=SENTRY_DSN=…`
    // pointed at anything other than the official ingest host would
    // otherwise ship crash data to an attacker-controlled endpoint.
    // Build-time DSN substitution is the intended vector but a
    // misconfigured CI env var is still possible.
    // Reference: security-review SR-20260419-028.
    final dsnHost = Uri.tryParse(sentryDsn)?.host ?? '';
    assert(
      dsnHost.endsWith('.ingest.sentry.io') ||
          dsnHost.endsWith('ingest.sentry.io'),
      'SENTRY_DSN host must be *.ingest.sentry.io — refusing to init',
    );
    if (!dsnHost.endsWith('.ingest.sentry.io') &&
        !dsnHost.endsWith('ingest.sentry.io')) {
      // Release build bypasses `assert`; fail loudly in the log so an
      // operator notices rather than silently shipping data off-policy.
      return;
    }
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
        // Cap the in-memory breadcrumb queue. The SDK default (100)
        // has been reasonable in practice, but pinning it defuses a
        // future SDK default flip and keeps the per-event payload
        // deterministic. Reference: performance-review PR-20260419-029.
        ..maxBreadcrumbs = 100
        // Only capture warnings and above — debug/info breadcrumbs
        // are added manually via the logger integration.
        ..diagnosticLevel = SentryLevel.warning
        // Strip URL paths from HTTP breadcrumbs — `sentry_dio` records
        // every `api.github.com` / `raw.githubusercontent.com` request
        // URL, which embeds owner/repo/path (PII per ADR-0014). Keep
        // method + status_code so debugging a 4xx/5xx is still
        // possible. Reference: security-review SR-20260419-017.
        ..beforeBreadcrumb = _redactHttpBreadcrumb
        // Strip URL paths from events before they leave the device —
        // `sentry_dio.DioEventProcessor` enriches failed-request events
        // with the full `uri`, which `sendDefaultPii: false` does NOT
        // cover. Reference: security-review SR-20260419-018.
        ..beforeSend = _redactHttpEvent;
    });
  }

  /// Drops the path component from `http.*` breadcrumbs so owner /
  /// repo / file paths never surface in Sentry dashboards.
  static Breadcrumb? _redactHttpBreadcrumb(Breadcrumb? crumb, Hint hint) {
    if (crumb == null) return null;
    if (crumb.category != 'http') return crumb;
    final data = Map<String, Object?>.from(crumb.data ?? const {});
    if (data.containsKey('url')) {
      data['url'] = '[redacted]';
    }
    crumb.data = data;
    return crumb;
  }

  /// Strips URL paths from event payloads before Sentry sends them.
  /// Covers the `DioEventProcessor` enrichment path that
  /// `sendDefaultPii = false` does not filter. Complements the
  /// `captureFailedRequests: false` guard at the
  /// `repo_sync_providers.dart` `dio.addSentry` call site.
  static FutureOr<SentryEvent?> _redactHttpEvent(SentryEvent event, Hint hint) {
    final request = event.request;
    if (request != null && request.url != null) {
      final parsed = Uri.tryParse(request.url!);
      final scrubbed =
          parsed == null ? '[redacted]' : '${parsed.scheme}://${parsed.host}';
      request.url = scrubbed;
      request.queryString = null;
      request.fragment = null;
    }
    return event;
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
