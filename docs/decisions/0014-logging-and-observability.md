# ADR-0014 — Logging, crash reporting, and observability

**Status:** Accepted
**Date:** 2026-04-16
**Deciders:** Cemil Ilık

## Context

MarkdownViewer shipped its first TestFlight + Play Console internal
build (v0.2.1) with zero production observability. No unhandled
exception handler, no crash reporting, no structured logging, no
remote log sink. If a TestFlight user reports "the app crashed when
I opened file X", there is no way to see what happened.

## Decision

### Local observability (error hooks + structured logging)

Ship the smallest set of changes that lets the maintainer **see
production crashes and errors** without adding a cloud dependency
or requiring user consent:

1. **Wire Flutter's error hooks** — `FlutterError.onError` and
   `PlatformDispatcher.instance.onError` in `main.dart` catch
   framework and async errors, log them via the existing
   `appLoggerProvider`, and keep the red screen in debug mode.

2. **Add missing log call sites** — mermaid render failures,
   GitHub sync errors, and viewer prerender failures now carry
   `.w()` logs with sanitized context (error type, HTTP status,
   diagram type — never PAT, file contents, or full paths).

3. **Structured JSON output** — release mode uses `LogfmtPrinter`
   (structured key=value lines) at `Level.warning`; debug mode
   keeps `PrettyPrinter` at `Level.debug`. This makes future
   remote-sink integration a wiring change, not a format migration.

### Remote crash reporting (Sentry)

For production visibility beyond local logs:

1. **Provider:** Sentry (`sentry_flutter` + `sentry_dio`) — no
   Google account required, generous free tier (5K errors/month),
   performance tracing included.

2. **Network exception:** ADR-0011 restricts network to `repo_sync`
   only. Sentry is granted a narrow carve-out: `sentry_flutter` may
   send crash reports to `*.ingest.sentry.io` only, opt-in, with a
   user-visible toggle in Settings.

3. **Privacy model:** User must explicitly opt in via Settings >
   Crash Reporting (default: off). No telemetry without consent.
   The toggle explains what data is sent: crash stack traces, device
   model, OS version — no file contents, no PAT, no browsing history.

4. **DSN injection:** via `--dart-define=SENTRY_DSN` at build time.
   When DSN is absent (local dev), Sentry is a complete no-op with
   zero overhead.

5. **Dio integration:** `dio.addSentry()` records HTTP breadcrumbs
   and performance spans when Sentry is active.

6. **Navigation observer:** `SentryNavigatorObserver` in GoRouter
   records screen transitions as breadcrumbs.

## Alternatives Considered

### Ship Sentry from day one (skip local-only phase)

Rejected because the error hooks + structured logging provide
immediate local-device visibility with zero new dependencies,
which is sufficient for an internal-testing audience of one.
Sentry adds value once beta testers are involved.

### Firebase Crashlytics instead of Sentry

Rejected. Crashlytics requires a Firebase project,
`google-services.json` / `GoogleService-Info.plist`, and the
Google Analytics SDK as a transitive dependency — heavier setup
for a single-developer project. Sentry is leaner.

### Do nothing until v1.0

Rejected. The release pipeline is live, builds are reaching
TestFlight. Even with a single internal tester, undiagnosed
crashes waste debugging time.

## Consequences

### Positive

- Framework-level crashes and uncaught async errors are caught
  and logged instead of silently vanishing
- Mermaid render failures and network errors become diagnosable
  without reproducing the exact scenario
- JSON-structured release logs are ready for any future remote sink
- Sentry provides production crash visibility with consent-gated
  privacy model

### Negative

- Local stdout logs are only visible via `flutter logs` or Xcode
  console — Sentry closes this gap for production
- `sentry_flutter` + `sentry_dio` add two runtime dependencies

### Neutral

- No analytics or event tracking — the app has no monetization
  or growth metrics to track
- If analytics become desirable, that is a separate ADR with its
  own privacy review

## Security Rules

- **Never log:** GitHub PAT, file contents, full filesystem paths
- **Safe to log:** error types, HTTP status codes, short identifiers
  (SHA hashes, bundle IDs), sanitized path basenames
- **Sentry data:** crash stack traces, device model, OS version,
  app version, navigation breadcrumbs — no document content
