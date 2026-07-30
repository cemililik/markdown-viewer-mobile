# ADR-0020: Privacy-safe observability and release activation

This ADR defines when production observability may activate and how all emitted
diagnostics are made safe.

- **Status**: Accepted
- **Date**: 2026-07-30
- **Deciders**: Cemil Ilık
- **Owner**: Cemil Ilık
- **Revisit date**: 2026-09-30
- **Supersedes**:
  [ADR-0014](0014-logging-and-observability.md) in full, and only the Sentry
  exception and ingest-host wording in
  [ADR-0011](0011-network-access-policy.md). ADR-0011's repo-sync and
  user-initiated network rules remain in force.

## Context

The application has local structured logging and consent-gated Sentry wiring,
but signed Android and iOS builds do not inject `SENTRY_DSN`. The Settings
toggle can therefore appear enabled while production reporting is unavailable.

Simply injecting the DSN would activate latent privacy and lifecycle defects:

- event redaction currently covers only the request URL;
- exception messages can contain absolute paths;
- breadcrumbs can contain raw links or repository paths;
- tracing is enabled without a transaction scrubber;
- consent transitions can overlap, allowing initialization to race with
  revocation;
- a `finally` failure can mask consent-persistence failure;
- the in-app disclosure does not enumerate the data sent;
- release symbols are retained as workflow artifacts but not uploaded to
  Sentry; and
- obfuscated production failures are difficult to diagnose without symbol
  processing.

Crash reporting must become useful without transmitting document content,
credentials, paths, user-entered text, or other personally identifiable
information.

## Decision

### Activation order

Release activation is a two-stage change with a hard dependency:

1. Complete and verify the privacy boundary: centralized redaction, serialized
   consent, truthful disclosure, ingest-host validation, transaction policy,
   and control tests.
2. Only then inject `SENTRY_DSN` into signed builds.

This orders privacy-boundary hardening (roadmap item `W0-18`) before Sentry DSN
injection (roadmap item `W0-01`). The two stages may ship in one reviewed
release only when CI proves all stage-one gates before either signed build
command executes.

Until a build has a valid DSN, Settings hides or disables the crash-reporting
toggle and states that reporting is unavailable in that build. It cannot show
an enabled capability backed by no reporter.

### Consent state machine

Crash reporting remains explicitly opt-in and defaults to off. Consent
transitions run through one serialized state machine; concurrent enable,
disable, startup, and shutdown transitions cannot overlap.

Enable follows this order:

1. validate that the build has an allowed DSN;
2. durably persist consent;
3. initialize Sentry with the privacy configuration; and
4. publish the enabled UI state.

If initialization fails, runtime state remains off, the preference is rolled
back where storage is available, and the user receives an actionable error.

Disable follows this order:

1. immediately prevent new capture and close Sentry;
2. durably persist revoked consent; and
3. publish the disabled UI state.

If revocation persistence fails, Sentry remains off for the process, the UI
does not claim durable success, and the user receives a retry action explaining
that the choice could not be saved. Startup initializes Sentry only from a
complete, valid persisted consent record; incomplete transition records are
fail-closed.

No lifecycle `finally` block may replace the original persistence error.
Transitions expose pending state so the toggle is disabled while work is in
flight.

### One redaction boundary

All local and remote diagnostics pass through one allow-list-based redaction
component before formatting, logging, breadcrumb creation, event capture, or
transaction capture.

The following data is forbidden:

- GitHub PATs, authorization headers, cookies, DSNs, and credentials;
- document, diagram, PDF, and search contents;
- full filesystem paths and portable path tokens;
- raw URL paths, query strings, fragments, and user-entered links;
- repository owner, repository name, branch, and file path;
- form input, search queries, filenames when a category is sufficient;
- response bodies and request bodies;
- device advertising or persistent user identifiers;
- screenshots, view hierarchies, attachments, and clipboard contents; and
- Sentry user identity or default PII collection.

Allowed structured fields are:

- stable failure code;
- sanitized operation category;
- HTTP status;
- allow-listed host category;
- route template without arguments;
- app version, build, platform, and OS version;
- coarse device model supplied by the SDK;
- diagram type when it can be derived without source text; and
- non-reversible, purpose-specific aggregate counters.

The redactor is applied to:

- local logger messages and structured fields;
- `beforeBreadcrumb`;
- `beforeSend`;
- `beforeSendTransaction`;
- Dio breadcrumbs and spans;
- Flutter and platform unhandled-error hooks; and
- provider-failure observation.

If an event or transaction contains an unrecognized string-bearing field that
cannot be proven safe, the hook drops it. Privacy failure is fail-closed, even
when that reduces observability.

Mermaid and parser diagnostics are classified into stable categories. Raw
engine messages are neither logged nor sent.

### Tracing policy

Performance tracing is disabled with `tracesSampleRate = 0` until:

- `beforeSendTransaction` removes raw descriptions, span operations, URLs, and
  resource names not on the allow-list;
- tests seed canary paths, PATs, repository coordinates, queries, and document
  excerpts into every transaction field and prove none survive; and
- the privacy disclosure explicitly includes performance telemetry.

After those conditions pass, tracing may be enabled at a maximum initial sample
rate of 0.1 for consented release users. Raising the rate or adding profiling,
replay, screenshots, or attachments requires a superseding ADR and privacy
review.

### DSN and network policy

Local and unsigned development builds may omit the DSN; Sentry is then a
complete no-op.

Signed release builds are fail-closed:

- `SENTRY_DSN` arrives from a protected CI secret through step-level `env`;
- it is never interpolated directly into a shell `run` expression;
- an empty, malformed, non-HTTPS, credential-bearing, or disallowed-host DSN
  fails the build before signing;
- both Android and iOS signed build commands receive the same validated value;
  and
- CI parses the workflow and asserts the guard and both injections exist.

Runtime validation repeats the build check. Allowed hosts follow the narrow
Sentry ingest grammar: `ingest.sentry.io`, a subdomain of
`ingest.sentry.io`, or an organization host under
`ingest.<region>.sentry.io`. Arbitrary `*.sentry.io` hosts are rejected.
Rejected DSNs log only a stable configuration code, never the DSN.

Sentry remains the only network exception outside `repo_sync`, is initialized
only with durable consent, and sends only to the validated ingest host.

### Capture ownership and signal quality

Unhandled Flutter, platform, Riverpod provider, and application failures each
have one capture owner. SDK integration and manual hooks must not report the
same failure twice.

Expected cancellation is not captured. Recoverable failures are logged once at
warning level. Terminal unexpected failures include the original sanitized
stack trace. Repeated per-file sync warnings are summarized into one sanitized
outcome containing aggregate counts.

Application logger warnings and errors may become Sentry breadcrumbs only after
redaction and only while Sentry is enabled.

### Disclosure

Settings presents localized disclosure adjacent to the toggle and links to the
localized privacy policy. It states:

- the categories collected;
- that document content, paths, repository coordinates, PATs, and user-entered
  text are excluded;
- whether performance tracing is active;
- the processor and purpose;
- how to revoke consent; and
- that local logging continues on-device when remote reporting is off.

Consent copy and the privacy policy must match the actual SDK options.

### Symbol processing

Every obfuscated signed release uploads the matching Dart debug information and
native symbols to the configured Sentry project:

- Dart split-debug-info and obfuscation maps;
- Android mapping and native symbols when produced; and
- iOS dSYM files.

Upload credentials are separate least-privilege CI secrets and never enter the
application artifact. A symbol upload failure fails the release job because an
un-symbolicated obfuscated release does not satisfy the observability goal.
The workflow retains the same files as recovery artifacts under the documented
retention policy.

The symbol uploader and any new top-level dependency require the normal
dependency review. Accepting this ADR authorizes the architectural capability,
not an unreviewed version or mutable CI action.

### Verification requirements

CI must prove:

- stage-one privacy tests pass before DSN injection is permitted;
- all event, breadcrumb, transaction, log, and provider-observer canaries are
  removed or cause the item to be dropped;
- enable/disable/startup races resolve to the latest durable choice;
- preference and initialization failures preserve the original error and fail
  closed;
- no capture happens before consent or after runtime revocation;
- the toggle is unavailable when the build has no DSN;
- invalid DSN schemes and host shapes are rejected without logging the value;
- both signed build commands use the guarded environment value;
- tracing cannot become non-zero without the transaction-redaction suite; and
- a release fixture's crash resolves to source after symbol upload.

## Consequences

### Positive

- Production crash reporting becomes both active and privacy-bounded.
- Consent revocation cannot race with initialization.
- Event and transaction data follow the same policy as local logs.
- Signed builds cannot silently ship with a misleading, inert toggle.
- Obfuscated stack traces remain actionable.
- The release workflow encodes activation order rather than relying on
  contributor memory.

### Negative

- Fail-closed redaction can discard diagnostically useful events.
- Signed releases depend on Sentry and symbol-upload secret availability.
- Serialized consent and rollback behavior add state-machine complexity.
- Transaction tracing remains unavailable until its separate redaction tests
  pass.

### Neutral

- Local structured warning and error logs remain available without consent and
  do not leave the device.
- This decision authorizes crash diagnostics and bounded performance tracing,
  not analytics, product telemetry, session replay, or growth tracking.

## Alternatives considered

### Inject the DSN immediately and harden later

Rejected. It would turn currently latent path, content, transaction, and consent
defects into production data transmission.

### Keep Sentry optional in signed builds

Rejected. A signed build with an enabled-looking toggle and no reporter is not
an honest or testable release configuration.

### Keep tracing at 0.3 without transaction redaction

Rejected. HTTP span descriptions can contain repository and file coordinates,
and event redaction does not sanitize transactions.

### Use a deny-list redactor

Rejected. New SDK fields and new call sites would bypass a list of known bad
keys. An allow-list with fail-closed handling is safer.

### Capture all SDK defaults and rely on consent

Rejected. Consent does not authorize document content, credentials, paths, or
unbounded personally identifiable information.

### Retain symbols as CI artifacts without upload

Rejected. Manual symbol recovery is slow and fragile during incident response,
especially for obfuscated release builds.
