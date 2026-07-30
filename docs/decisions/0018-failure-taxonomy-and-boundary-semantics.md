# ADR-0018: Failure taxonomy and boundary semantics

This ADR defines the application-wide typed failure vocabulary and ownership of
error conversion at layer boundaries.

- **Status**: Accepted
- **Date**: 2026-07-30
- **Deciders**: Cemil Ilık
- **Owner**: Cemil Ilık
- **Revisit date**: 2026-10-30
- **Supersedes**: the Error Handling section of
  [ADR-0012](0012-document-sync-architecture.md). ADR-0012's sync architecture
  remains in force.

## Context

The project uses a sealed `Failure` hierarchy, but the authoritative list is a
sync-specific section of ADR-0012 rather than an application-wide decision.
The list and implementation have drifted:

- `PathNotFoundFailure` was decided but is absent;
- `AuthFailure` and `RepoTooLargeFailure` ship without a recorded decision;
- `RenderFailure` and `PartialSyncFailure` are never constructed;
- Mermaid uses a separate result hierarchy for recoverable block failures;
- invalid remote paths are reported as unsupported providers;
- cancellation, timeout, encoding failure, certificate rejection, redirect
  rejection, response-size limits, and storage exhaustion have no distinct
  types;
- equivalent failures have no semantic equality;
- boundary conversion discards the original stack trace; and
- wildcard mapper branches defeat sealed-hierarchy exhaustiveness.

These gaps collapse failures that require different user actions. For example,
offline connectivity and a wall-clock timeout need different messages, as do a
TLS certificate rejection and an oversized response.

## Decision

### Failure contract

`Failure` remains a sealed, immutable domain type implementing `Exception`.
Every concrete failure contains:

- a stable, non-obfuscated `code`;
- a sanitized developer-facing `message`;
- an optional original `cause`;
- an optional original `stackTrace`; and
- typed, non-sensitive metadata required for recovery or localization.

`message`, `cause`, and `stackTrace` are never shown directly to the user.
`toString()` emits the stable code and safe structured metadata only. It never
interpolates the cause, a runtime type name, user input, a full path, a URL
path, a response body, or document content.

Semantic equality uses the concrete failure type, stable code, and typed
recovery metadata. It excludes `message`, `cause`, and `stackTrace`, because
those values describe diagnostic provenance rather than a different
user-visible state. Each subtype must declare its equality fields explicitly.

### Complete taxonomy

The following concrete types are the application-wide vocabulary:

| Failure | Meaning and recovery |
|---|---|
| `FileNotFoundFailure` | A selected local file no longer exists; choose another file. |
| `PermissionDeniedFailure` | The OS denied local access; grant or renew access. |
| `EncodingFailure` | Bytes use an unsupported encoding; use a supported encoding. |
| `ParseFailure` | Supported text could not be parsed as a document; offer raw source. |
| `StorageFailure` | Local persistence failed for a reason other than exhaustion; retry. |
| `StorageExhaustedFailure` | The device has insufficient writable space; free space. |
| `PlatformUnavailableFailure` | A required plugin or platform channel is unavailable. |
| `NativeContractFailure` | A native response, event, or error code violated the versioned channel contract. |
| `CancellationFailure` | The user or owning lifecycle cancelled the operation. |
| `TimeoutFailure` | A wall-clock operation deadline elapsed; retry when appropriate. |
| `NetworkUnavailableFailure` | A connection could not be established; restore connectivity. |
| `CertificateFailure` | TLS certificate validation failed; do not suggest insecure bypass. |
| `RedirectPolicyFailure` | A redirect violated the host or hop policy. |
| `ResponseTooLargeFailure` | A response or rendered artifact exceeded its size cap. |
| `RateLimitedFailure` | The provider rate limit is exhausted; wait or use a valid PAT. |
| `AuthFailure` | Authentication or authorization failed; repair or remove the PAT. |
| `RepoNotFoundFailure` | The repository does not exist or is not visible. |
| `PathNotFoundFailure` | The repository exists but the requested sub-path does not. |
| `RepoTooLargeFailure` | Discovery exceeds the supported repository ceiling. |
| `UnsupportedProviderFailure` | The supplied repository URL uses no supported provider. |
| `InvalidRemotePathFailure` | Remote path data fails traversal or containment validation. |
| `RemoteServiceFailure` | A valid remote request failed with another actionable service response. |
| `SyncAlreadyRunningFailure` | Another sync owns the repository operation; attach to or show that operation. |
| `RenderFailure` | A required render operation failed at an operation boundary. |
| `UnknownFailure` | An unexpected non-programming error has no more specific mapping. |

This list is closed. Adding, removing, or merging a member requires updating
this ADR through a superseding ADR, the exhaustive mapper test, and both locale
catalogs.

`PartialSyncFailure` is removed. A sync with successful and failed files is a
typed partial `SyncResult`, not an exception. It carries failed file records and
retry information.

Recoverable block rendering remains a result union such as
`MermaidRenderSuccess | MermaidRenderFailure`. It becomes `RenderFailure` only
when a repository or use case cannot satisfy its operation because rendering
failed. This preserves inline degradation without creating a parallel thrown
exception taxonomy.

`CancellationFailure` is a terminal, non-error outcome for logging and
observability. Presentation may render a neutral cancelled state or no message.
It is never reported to Sentry as a crash.

### Mapping rules

Every low-level failure maps deterministically:

- connection, send, receive, and operation deadlines map to
  `TimeoutFailure`;
- explicit cancellation maps to `CancellationFailure`;
- certificate rejection maps to `CertificateFailure`;
- connection establishment failure maps to `NetworkUnavailableFailure`;
- redirect rejection maps to `RedirectPolicyFailure`;
- byte-cap termination maps to `ResponseTooLargeFailure`;
- HTTP responses map by status and provider semantics to rate-limit,
  authentication, repository, path, size, or remote-service failures; and
- disk-full and quota errors map to `StorageExhaustedFailure`, not
  `UnknownFailure`.

No failure type may double as an unrelated security rejection.
`UnsupportedProviderFailure` therefore cannot represent traversal or sandbox
escape.

Every concrete type maps to exactly one localized message key and recovery
policy. Presentation switches are exhaustive and have no wildcard/default arm.
The mapper may select parameterized copy from typed safe metadata, but never
from `message` or `cause`.

### Boundary responsibilities

The layer that owns an external boundary performs the conversion:

- data adapters catch filesystem, database, HTTP, secure-storage, plugin, and
  platform-channel errors and throw a typed `Failure`;
- application code catches `Failure`, preserves it and its stack trace, and
  publishes the appropriate state or result;
- operation-local cancellation machinery may use a private exception
  internally, but it must become `CancellationFailure` before crossing the
  application boundary;
- presentation consumes only `Failure` or typed result state and never renders
  raw exception text; and
- programming errors and violated internal invariants are not disguised as
  recoverable failures at an inner boundary. They reach the application-level
  unhandled-error hooks.

All conversion catches bind both values:

```dart
try {
  return await source.read();
} on Failure {
  rethrow;
} on FileSystemException catch (error, stackTrace) {
  throw StorageFailure(
    message: 'Local persistence failed',
    cause: error,
    stackTrace: stackTrace,
  );
}
```

The original stack trace is passed to `AsyncValue.error`, structured logging,
and crash reporting when the failure is reportable.

An error is logged once at the boundary that decides its terminal outcome.
Intermediate layers may add typed context, but must not emit duplicate error
events. Recoverable expected outcomes use warning or informational diagnostics
according to the observability standard.

### Verification requirements

Automated tests must:

- enumerate every concrete subtype and fail when the hierarchy changes;
- prove every subtype has one English and Turkish message mapping;
- prove presentation and sync mappers contain no wildcard arm;
- table-test every `DioExceptionType`, relevant HTTP status, platform error
  code, and filesystem exhaustion case;
- prove conversion preserves the original stack trace;
- prove semantic equality ignores diagnostic provenance and includes recovery
  metadata;
- prove cancellation is not logged or captured as a crash;
- prove raw cause/message data cannot reach localized copy; and
- prove partial sync is a result with retryable failed items.

## Consequences

### Positive

- The compiler forces every consumer to handle new failure semantics.
- Users receive distinct, actionable messages for distinct recovery paths.
- Security rejections no longer masquerade as ordinary URL errors.
- Original stack traces remain useful in obfuscated production builds.
- Semantic equality prevents repeated equivalent state notifications.
- Partial success and recoverable render degradation are modeled as results
  rather than exceptional control flow.

### Negative

- Existing boundary adapters, mappers, ARB files, and tests must migrate
  together.
- The hierarchy contains more concrete types than the current implementation.
- Equality metadata requires discipline in every subtype.

### Neutral

- `Failure` remains an exception at repository boundaries; this ADR does not
  require an `Either` or `Result` package.
- Internal result unions remain valid where failure is an expected,
  locally recoverable outcome.

## Alternatives considered

### Keep the taxonomy inside ADR-0012

Rejected. Failure semantics are shared by file loading, storage, platform
channels, rendering, export, and sync.

### Use one failure type with error codes

Rejected. It would move exhaustiveness from the Dart type system to runtime
string comparisons and make unrelated metadata nullable.

### Convert every operation to `Result<T, Failure>`

Rejected for now. It is a repository-wide API migration that is not required
to establish typed boundaries and exhaustive presentation mapping.

### Treat cancellation as an untyped private exception everywhere

Rejected. Private cancellation machinery is valid inside one operation, but
crossing a boundary without typed semantics causes cancellation to appear as an
unknown error or successful completion.

### Include diagnostic provenance in equality

Rejected. Different exception instances and stack traces can describe the same
recoverable user state and would cause redundant Riverpod notifications.
