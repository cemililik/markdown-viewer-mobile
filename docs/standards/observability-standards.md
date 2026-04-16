# Observability Standards

Rules for logging, crash reporting, and production diagnostics.
See [ADR-0014](../decisions/0014-logging-and-observability.md) for
the architectural decision behind these choices.

## Principles

1. **Observe without compromising privacy** — never log secrets,
   file contents, or personally identifiable information
2. **Consent before transmission** — no data leaves the device
   without explicit user opt-in
3. **Structured output** — logs must be machine-parseable in
   release mode for future remote-sink integration
4. **Minimum viable noise** — log warnings and errors, not
   routine operations; release-mode level floor is `Level.warning`

## Logger Configuration

| Mode | Printer | Level |
|------|---------|-------|
| Debug | `PrettyPrinter` | `Level.debug` |
| Release | `LogfmtPrinter` | `Level.warning` |

The shared logger instance is provided via `appLoggerProvider`
(Riverpod). Feature code must use the provider, never
instantiate `Logger()` directly.

## What to Log

| Scenario | Level | Required context |
|----------|-------|------------------|
| Unhandled framework error (`FlutterError.onError`) | `.e()` | Exception type + stack trace |
| Uncaught async error (`PlatformDispatcher.onError`) | `.e()` | Exception type + stack trace |
| Mermaid render failure | `.w()` | Diagram type + error message |
| GitHub sync network error | `.w()` | HTTP status + URL path (no query params) |
| PDF prerender failure | `.w()` | Diagram type + error message |
| Reading position store corruption | `.e()` | Error type (no file path) |

## What Never to Log

- GitHub Personal Access Token (or any credential)
- File contents or full filesystem paths
- User-entered text (search queries, form input)
- Device identifiers beyond what Sentry collects with consent

Safe to log: error types, HTTP status codes, SHA hashes, bundle
IDs, sanitized path basenames (filename only, no directory).

## Crash Reporting (Sentry)

### Consent Model

- **Default: off.** The `crashReporting` preference in
  `ConsentStore` defaults to `false`.
- Users enable it via **Settings > Crash Reporting**.
- The toggle label explains what data is sent.
- Toggling off calls `Sentry.close()` immediately.

### DSN Injection

The Sentry DSN is injected at build time via
`--dart-define=SENTRY_DSN=<value>`. When the DSN is absent
(local development), Sentry initialization is skipped entirely
with zero runtime overhead.

### Data Sent to Sentry

| Data | Included | Notes |
|------|----------|-------|
| Crash stack traces | Yes | Core diagnostic value |
| Device model + OS version | Yes | Standard Sentry context |
| App version | Yes | For regression tracking |
| Navigation breadcrumbs | Yes | Which screens were visited |
| HTTP breadcrumbs (Dio) | Yes | URL + status, no body or headers |
| Document content | **No** | Never attached to events |
| File paths | **No** | Only basenames in breadcrumbs |
| GitHub PAT | **No** | Stripped at the Dio interceptor level |

### Network Policy

Sentry is the only exception to [ADR-0011](../decisions/0011-network-access-policy.md)'s
network restriction outside `repo_sync`. Allowed hosts:
`*.ingest.sentry.io` — only when consent is granted.

## Error Hooks

Both hooks are wired in `main.dart` before `runApp`:

```dart
FlutterError.onError = (details) {
  FlutterError.presentError(details);  // red screen in debug
  logger.e('FlutterError', error: details.exception, stackTrace: details.stack);
  // Forward to Sentry explicitly — `SentryFlutter.init` does NOT
  // auto-hook `FlutterError.onError`. Guard with `Sentry.isEnabled`
  // so the branch is a no-op when the user has not opted in or the
  // build has no DSN.
  if (Sentry.isEnabled) {
    Sentry.captureException(details.exception, stackTrace: details.stack);
  }
};

PlatformDispatcher.instance.onError = (error, stack) {
  logger.e('PlatformDispatcher', error: error, stackTrace: stack);
  return true;  // handled
};
```

## Adding New Log Sites

When adding a new log call:

1. Choose the correct level (`.w()` for recoverable, `.e()` for
   unrecoverable)
2. Include enough context to diagnose without reproducing
3. Strip any sensitive data before logging
4. Verify the log appears in `flutter logs` during development
5. If the error is user-facing, also surface it through the
   existing `Failure` → `ErrorView` pipeline (see
   [error-handling-standards.md](error-handling-standards.md))
