# ADR-0014 — Logging, crash reporting, and observability

**Status:** Proposed
**Date:** 2026-04-16
**Deciders:** Cemil Ilık

## Context

MarkdownViewer shipped its first TestFlight + Play Console internal
build (v0.2.1) on 2026-04-15. The app has a typed `Failure` hierarchy,
a `logger` package instance, and an `ErrorView` widget — but zero
production observability. Specifically:

| Capability | Current state |
|---|---|
| Unhandled exception handler | None — `FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded` are all unconfigured |
| Crash reporting | None — no Sentry, Firebase Crashlytics, or equivalent |
| Structured logging | None — six `logger.e()` call sites output to stdout only |
| Remote log sink | None — logs vanish on app exit |
| Analytics / telemetry | None — no event tracking |
| Network request logging | None — Dio errors mapped to typed failures but request/response details are not logged |
| Mermaid render error logging | None — error shown to user but not logged |

If a TestFlight user reports "the app crashed when I opened file X",
there is currently no way to see what happened.

## Decision

### Phase 1 — Minimum viable observability (this ADR)

Ship the smallest set of changes that lets the maintainer **see
production crashes and errors** without adding a cloud dependency
or requiring user consent UX:

#### 1. Wire Flutter's error hooks in `main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch synchronous framework errors (layout, paint, build).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);     // keeps red screen in debug
    logger.e('FlutterError', error: details.exception, stackTrace: details.stack);
  };

  // Catch uncaught async errors from the platform.
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.e('PlatformDispatcher', error: error, stackTrace: stack);
    return true;  // mark as handled so the app doesn't terminate
  };

  // ... rest of init ...
  runApp(...);
}
```

No new dependency. No network. No user consent.
All logged via the existing `appLoggerProvider` to stdout.

#### 2. Add missing log call sites

| Where | What to log | Level |
|---|---|---|
| `mermaid_renderer_impl.dart` — `_handleChannelResult` error branch | `MermaidRenderFailure.message` + diagram source hash | `.w()` |
| `github_sync_provider.dart` — every `_mapDioError` exit | HTTP status + URL path (no query params, no PAT) | `.w()` |
| `viewer_screen.dart` — `_prerenderMermaidDiagrams` failure branch | Diagram type + error message | `.w()` |
| `reading_position_store_impl.dart` — already has `.e()` | ✅ Already done | — |

Security rule: **never log the GitHub PAT, file contents, or
full filesystem paths.** Only log error types, HTTP status codes,
short identifiers (SHA hashes, bundle IDs), and sanitized path
basenames.

#### 3. Structured JSON output (logger configuration)

Switch the existing `Logger()` constructor to emit JSON-formatted
lines when running in release mode:

```dart
Logger(
  printer: kReleaseMode
      ? JsonPrinter()  // structured output for future remote sinks
      : PrettyPrinter(),  // human-friendly for local dev
);
```

`JsonPrinter` is built into `package:logger`. Each line becomes a
self-contained JSON object with `level`, `message`, `error`,
`stackTrace`, `time` fields. This makes future remote-sink
integration (Phase 2) a one-line wiring change instead of a
format migration.

### Phase 2 — Remote crash reporting (deferred, separate ADR)

**Not part of this ADR.** When the time comes:

- **Provider choice:** Sentry is preferred over Firebase Crashlytics
  because it does not require a Google account, has a generous free
  tier (5K errors/month), and provides performance tracing. But this
  is a decision for Phase 2's own ADR.
- **Network access exception:** ADR-0011 restricts network to
  `repo_sync` only. Crash reporting needs an exception. Phase 2's
  ADR will propose a narrow carve-out: `sentry_flutter` may send
  crash reports to `*.ingest.sentry.io` only, opt-in, with a
  user-visible toggle in Settings.
- **Privacy model:** User must explicitly opt in via a Settings
  toggle (default: off). No telemetry without consent. The toggle
  text explains what data is sent (crash stack traces, device model,
  OS version — no file contents, no PAT, no browsing history).
- **Analytics:** Not planned. The app has no monetization and no
  growth metrics to track. If analytics become desirable, that is
  a separate ADR with its own privacy review.

## Alternatives considered

### 1. Ship Sentry now (Phase 1 + 2 combined)

Rejected because:
- Adds `sentry_flutter` dependency (new package, new ADR-0011
  exception, consent UX)
- Requires a Sentry project + DSN secret
- Increases scope of this ADR beyond "minimum viable"
- The hooks + structured logging in Phase 1 already provide
  local-device visibility, which is sufficient for an internal-
  testing audience of one

### 2. Use Firebase Crashlytics instead of Sentry

Deferred to Phase 2. Crashlytics requires a Firebase project,
`google-services.json` / `GoogleService-Info.plist`, and the
Google Analytics SDK as a transitive dependency — heavier setup
for a single-developer project. Sentry is leaner.

### 3. Do nothing until v1.0

Rejected. The release pipeline is live, builds are reaching
TestFlight. Even with a single internal tester, undiagnosed crashes
waste debugging time. Phase 1 is four small edits (main.dart hooks,
three new log calls, one logger config change) with zero new
dependencies.

## Consequences

### Positive

- Framework-level crashes and uncaught async errors are caught and
  logged instead of silently vanishing
- Mermaid render failures become visible in logs (currently silent)
- Network errors carry enough context to diagnose sync issues
  without reproducing
- JSON-formatted release logs are ready for a future remote sink
  with zero format migration

### Negative

- stdout JSON logs on a physical device are only visible via
  `flutter logs` or Xcode console — not yet accessible to the user
  or uploadable. Phase 2 (remote reporting) closes this gap.
- Six additional log call sites increase log volume; the logger's
  level filter should be set to `.warning` in release mode to keep
  noise low

### Neutral

- No new runtime dependency
- No network access change
- No user consent required (all logs stay on device)
- No UI change

## Implementation checklist

- [ ] Wire `FlutterError.onError` in `main.dart`
- [ ] Wire `PlatformDispatcher.instance.onError` in `main.dart`
- [ ] Add `.w()` log in `mermaid_renderer_impl.dart` error branch
- [ ] Add `.w()` log in `github_sync_provider.dart` error mapping
- [ ] Add `.w()` log in `viewer_screen.dart` mermaid prerender failure
- [ ] Switch logger to `JsonPrinter` in release mode
- [ ] Verify: `flutter analyze` clean, full test suite green
- [ ] Commit as `feat(observability): wire error hooks + structured logging`
