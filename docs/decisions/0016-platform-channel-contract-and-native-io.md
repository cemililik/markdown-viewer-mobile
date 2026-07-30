# ADR-0016: Versioned platform-channel contract and native I/O execution

- **Status**: Accepted
- **Date**: 2026-07-30
- **Deciders**: Cemil Ilık
- **Owner**: Cemil Ilık
- **Revisit date**: 2027-01-30
- **Depends on**:
  [ADR-0018](0018-failure-taxonomy-and-boundary-semantics.md)
- **Related**: [ADR-0009](0009-platform-scope.md),
  [ADR-0010](0010-testing-strategy.md)

This record proposes one versioned contract for every application-owned
Flutter/native boundary.

## Context

The application has native channels for folder access, inbound file-open events,
default-handler settings, and Android screen-capture protection. Their names,
payloads, error codes, limits, threading rules, and unsupported-platform behavior
are currently distributed across Dart, Kotlin, Swift, and comments.

That distribution has produced concrete drift:

- the folder channel uses a different namespace from the other channels;
- Android and iOS enforce different traversal limits and return different errors;
- Dart maps only a subset of native errors and uses unchecked payload casts;
- directory enumeration and file reads can execute on a platform main thread;
- a missing picker callback can leave an operation permanently busy;
- native security and containment code has no cross-platform contract test; and
- `file_picker` remains for one document-pick flow even though the application
  already maintains native document-access code.

The native boundary handles opaque grants, security-scoped bookmarks, untrusted
file metadata, and plaintext document bytes. It therefore needs one explicit,
versioned contract rather than three implementations that happen to look alike.

## Decision

### Contract ownership and versioning

All application-owned Flutter platform channels will use this namespace:

```text
com.cemililik.markdown_viewer/<capability>/v1
```

The repository will contain one machine-readable v1 contract fixture that
defines channel names, method or event names, request and response fields,
error codes, and limits. Dart, Kotlin, and Swift tests will consume equivalent
fixtures generated from or validated against that source. A contract change
that is not backward compatible requires a new channel version; an existing
version is not changed in place.

Channel access in Dart must be behind a typed domain port and a data-layer
adapter. Presentation code must not construct or invoke a `MethodChannel` or
`EventChannel` directly. Every channel is registered on both platforms.
Unsupported operations return the typed `UNSUPPORTED` error or a documented
`supported: false` result rather than relying on `MissingPluginException`.

### Channel registry

The v1 registry is exhaustive. CI will reject an application-owned channel
literal outside the registry.

| Channel | Kind | Operations |
|---------|------|------------|
| `library_folders/v1` | Method | Folder picker, listing, reads, release, cancellation |
| `document_access/v1` | Method | Document picker, reads, release, cancellation |
| `file_open/v1` | Event | File-open events and typed error events |
| `default_handler/v1` | Method | `getCapability`, `openSettings` |
| `screen_capture_guard/v1` | Method | `getCapability`, `setSecure` |
| `storage_policy/v1` | Method | `excludeFromBackup`, `getBackupExclusion` |

The exact registered method names are:

- `library_folders/v1`: `pickDirectory`, `listDirectory`,
  `listDirectoryRecursive`, `readFileBytes`, `releaseAccess`, and
  `cancelOperation`;
- `document_access/v1`: `pickMarkdownDocument`, `readDocumentBytes`,
  `releaseAccess`, and `cancelOperation`;
- `file_open/v1`: `onListen` and `onCancel`, emitting `documentOpened` or a
  typed error event;
- `default_handler/v1`: `getCapability` and `openSettings`;
- `screen_capture_guard/v1`: `getCapability` and `setSecure`; and
- `storage_policy/v1`: `excludeFromBackup` and `getBackupExclusion`.

`storage_policy/v1` is the native boundary used by
[ADR-0017](0017-local-content-storage-and-cache-lifecycle.md). Android may
report a capability as unsupported when its declarative backup rules, rather
than a runtime attribute, govern the requested path.

### Shared wire types

Every method request carries a non-empty `requestId`. Operations that can
outlive one frame also return or emit that identifier. Opaque handles are
named `accessHandle`; callers never infer whether a handle is an Android SAF
URI or an iOS security-scoped bookmark.

The contract uses only StandardMessageCodec values with explicitly validated
types: null, booleans, bounded integers, strings, byte arrays, lists, and
string-keyed maps. Native implementations validate every field before work
begins. Dart adapters validate every result before constructing a domain
object. Unknown, missing, or additional security-sensitive fields fail as
`MALFORMED_PAYLOAD`; unchecked `dynamic` casts are not permitted.

Directory results have this shape:

```text
{
  entries: [
    {
      relativePath: String,
      displayName: String,
      isDirectory: bool,
      byteLength: int?
    }
  ],
  nextCursor: String?,
  truncated: bool,
  truncationReason: String?
}
```

`relativePath` is relative to the granted root and uses `/` as its separator.
Native absolute paths and raw Android content URIs are not display strings.

Picker success has this shape:

```text
{
  accessHandle: String,
  displayName: String,
  relativePath: String?
}
```

A user dismissing a system picker is a successful null result. Programmatic
cancellation is the typed `CANCELLED` error. These states are not conflated.

### Method behavior

`pickDirectory` and `pickMarkdownDocument` launch the platform system picker
and retain the minimum access required for later reads. Exactly one picker may
be active per capability. Activity or scene detachment, engine detachment,
process restoration failure, and `cancelOperation` must complete the pending
request exactly once and release the busy state.

`listDirectory` returns one bounded page of immediate children.
`listDirectoryRecursive` returns bounded pages in stable relative-path order.
Reaching an operation limit returns the collected page with `truncated: true`
and a truthful `truncationReason`; it does not discard partial results.

`readFileBytes` and `readDocumentBytes` resolve the opaque access handle,
verify that the requested item remains inside the granted root, and stream
bytes through the size guard. They do not trust an advertised length alone.

`releaseAccess` releases an Android persistable URI permission or the
application's stored iOS bookmark reference. It is idempotent. iOS
`stopAccessingSecurityScopedResource` remains scoped to each actual access;
it is not deferred until source removal.

`getCapability` returns `{supported: bool, reason: String?}`.
`openSettings` and `setSecure` either perform the advertised action or return
`UNSUPPORTED`. They never report success for a no-op.

`excludeFromBackup` accepts an application-owned, already-contained path and
sets the platform backup-exclusion attribute. `getBackupExclusion` verifies
the effective state so startup reconciliation can fail visibly.

### Typed errors

The following codes are stable across Dart, Kotlin, and Swift:

| Code | Meaning |
|------|---------|
| `INVALID_ARGUMENT` | A request field is missing, misshaped, or outside its allowed range |
| `MALFORMED_PAYLOAD` | A native response or event violates the v1 schema |
| `UNSUPPORTED` | The platform cannot provide the capability |
| `BUSY` | A mutually exclusive picker is already active |
| `CANCELLED` | The caller cancelled an in-flight operation |
| `ACCESS_DENIED` | The platform grant is absent or cannot be claimed |
| `ACCESS_STALE` | A stored handle is stale; typed details may carry `replacementAccessHandle` |
| `NOT_FOUND` | The selected root or requested child no longer exists |
| `PATH_OUTSIDE_ROOT` | A normalized or symlink-resolved path escapes the granted root |
| `DEPTH_LIMIT_REACHED` | Traversal stopped at the maximum depth and returned partial results |
| `ENTRY_LIMIT_REACHED` | Traversal stopped at the maximum entry count and returned partial results |
| `FILE_TOO_LARGE` | A preflight or streaming byte limit was exceeded |
| `TIMEOUT` | A bounded native operation exceeded its deadline |
| `IO_FAILURE` | A platform I/O operation failed for a non-security reason |
| `INTERNAL` | An unexpected native failure was sanitized at the boundary |

Dart maps every code exhaustively to a typed failure. An unknown code maps to
`NativeContractFailure` with the code, channel, and method, but without raw
paths, access handles, file content, or native exception text. Native error
details are also schema-validated and privacy-safe. The one opaque exception,
`replacementAccessHandle`, is consumed by the access-handle store and must
never enter logs, analytics, Sentry, or user-facing error text.

Limit completion is represented in the page response. The corresponding
`DEPTH_LIMIT_REACHED` and `ENTRY_LIMIT_REACHED` codes are reserved for
operations that cannot encode a page, including event-channel intake and
pre-v1 compatibility adapters during migration.

### Initial limits

All limits are named once in the contract and enforced identically:

| Resource | Limit |
|----------|-------|
| One markdown document | 10 MiB |
| Recursive folder traversal depth | 10 levels below the granted root |
| Recursive folder entries | 2,000 entries |
| Directory page | 256 entries |
| Content-search bytes read from one folder operation | 50 MiB |
| Queued cold-start file-open events | 32 events and 50 MiB in total |
| Native non-picker operation | 30 seconds |

The traversal limits preserve the currently shipped Android safety boundary
while making the result partial and actionable. Increasing a security or
memory limit requires benchmark evidence, fixture updates, and review; it does
not require a new channel version when the wire shape is unchanged.

### Cancellation and threading

Every long-running request owns a cancellation signal keyed by `requestId`.
`cancelOperation` is idempotent and propagates to enumeration, streaming
reads, copies, hashing, and any child work. Dart cancellation on provider
disposal must invoke it. Native code checks cancellation before starting,
between entries or chunks, and before publishing a result.

The contract distinguishes Flutter's main isolate from each native platform's
main thread. Dart-side synchronous file work and CPU-heavy payload processing
must not run on the main isolate.

System picker presentation and Flutter result delivery run on the platform
main thread. Directory traversal, content resolver or file-coordinator reads,
copying, hashing, bookmark resolution that can block, and payload construction
run on a dedicated bounded worker executor. A result is marshalled to the main
thread exactly once. Worker tasks must not retain an activity, view controller,
result callback, or security-scoped resource after completion.

The event channel has a bounded queue, preserves event order, and releases its
sink on `onCancel`. Overflow produces a typed event and drops no already
acknowledged document silently.

### Native parity and security tests

The contract is accepted as implemented only when all of these gates pass:

- Dart adapter tests cover every valid response, every error code, null picker
  cancellation, malformed payloads, and unknown-code fallback.
- Kotlin local tests and Swift `RunnerTests` use the same fixture trees to
  prove ordering, normalization, containment, symlink rejection, depth and
  entry truncation, streaming byte caps, cancellation, and exactly-once
  completion.
- A parity test compares Android and iOS results and error codes for the same
  fixture cases.
- Integration tests prove that worker execution does not perform directory
  enumeration or document reads on the platform main thread.
- CI verifies that both native registries and all Dart channel literals match
  the machine-readable v1 registry.

### Replacing `file_picker`

The single-document library picker will migrate to
`document_access/v1`. The migration must land on both platforms, include the
contract and native tests above, and preserve system-picker accessibility
before `file_picker` is removed.

After the migration, remove `file_picker`, its generated registrant entries,
its iOS pod graph, and any permission description that existed solely for that
dependency. Lockfiles and platform privacy manifests must be regenerated and
reviewed. The application will not add another general-purpose picker plugin
for an operation covered by this contract.

## Consequences

### Positive

- Native behavior becomes explicit, versioned, typed, and testable across both
  platforms.
- Blocking file work cannot freeze Flutter's main isolate or a platform UI
  thread.
- Limits, cancellation, unsupported behavior, and error mapping become
  deterministic.
- Removing `file_picker` reduces dependency and iOS pod surface while keeping
  the system picker experience.
- Security-sensitive containment and grant-release behavior gain native and
  cross-platform regression coverage.

### Negative

- The project owns more Kotlin and Swift code and must maintain parity.
- Pagination, request identifiers, and cancellation add protocol complexity.
- Native test targets and fixture validation increase CI time.
- Migrating existing channel names requires a coordinated Dart/native release;
  mixed v0/v1 binaries are not supported.

## Alternatives considered

### Keep independent handwritten contracts

Rejected because the current error, limit, and payload drift is a direct
result of that model.

### Adopt Pigeon for all platform messages

Deferred. Pigeon would generate typed bindings, but it does not by itself
define threading, limits, cancellation, security-scoped resource lifetime, or
semantic parity. The versioned fixture leaves a future Pigeon migration open
without making it a prerequisite for these safety fixes.

### Keep `file_picker` for single-file selection

Rejected because one call site retains a broad plugin and its transitive iOS
surface while application-owned native access is already required for folder
permissions, byte caps, and containment.

### Return unlimited recursive results for compatibility

Rejected because it makes memory use and platform responsiveness depend on an
untrusted folder. Bounded partial results preserve useful work without hiding
the limit.
