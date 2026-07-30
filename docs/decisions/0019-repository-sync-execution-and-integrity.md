# ADR-0019: Repository sync execution, integrity, and resumability

- **Status**: Accepted
- **Date**: 2026-07-30
- **Deciders**: Cemil Ilık
- **Owner**: Cemil Ilık
- **Revisit date**: 2026-10-30
- **Supersedes**:
  [ADR-0012](0012-document-sync-architecture.md)
- **Amends**:
  [ADR-0011](0011-network-access-policy.md), only for continuation of an
  explicitly user-started sync
- **Depends on**:
  [ADR-0017](0017-local-content-storage-and-cache-lifecycle.md),
  [ADR-0018](0018-failure-taxonomy-and-boundary-semantics.md)

This record proposes a recoverable, cancellable, and user-initiated execution
model for repository synchronization.

## Context

ADR-0012 established a GitHub-first repository-sync feature, local mirrors,
bounded downloads, drift tracking, optional secure PAT storage, and a
GitHub Contents fallback for truncated trees. The implementation and a later
cross-cutting review exposed several gaps in that decision:

- file and database changes do not form a recoverable transaction;
- natural database keys and foreign-key enforcement are incomplete;
- a UI cancellation token does not reach every network, file, and database
  operation;
- the accepted “whole sync in `compute()`” model is not compatible with the
  root-isolate Dio and plugin graph;
- drift work and reads can still run on the UI isolate, and providers do not
  consistently observe database changes;
- GitHub `truncated: true` currently hard-fails despite ADR-0012's required
  Contents fallback;
- sync may become invisible or inconsistent when the app backgrounds;
- metered connections and aggregate download size are not communicated;
- PAT validation and reinstall lifecycle are underspecified; and
- hostile repository identifiers and paths can reach URL interpolation,
  writes, and recursive deletion without one end-to-end containment contract.

The new model must preserve ADR-0011's user-initiated network boundary while
allowing an already requested operation to finish safely. It must also be
honest about the impossibility of one atomic transaction spanning SQLite and a
filesystem.

## Decision

On acceptance, this ADR supersedes ADR-0012 in full. ADR-0017 is the
normative source for mirror placement, backup exposure, migration, portable
identity, cache lifecycle, and credential storage location. ADR-0011 remains
in force except for the narrowly defined background continuation below.

### Execution model

The sync coordinator runs asynchronously on the root Dart isolate. Dio,
Riverpod composition, secure-storage access, path-provider access, lifecycle
coordination, and progress publication stay on that isolate.

This is deliberate: asynchronous Dio sockets do not block the UI isolate while
waiting for network I/O, whereas moving the whole dependency graph into
`compute()` creates isolate-unsendable clients, cancellation tokens, plugin
channels, and database handles. “Background isolate” is not a substitute for
asynchronous I/O.

CPU-heavy, sendable work is dispatched to worker isolates:

- decoding and validating large GitHub tree or Contents responses;
- sorting and filtering large path sets;
- hashing large local or downloaded files; and
- building immutable diff plans.

Each worker accepts and returns immutable DTOs only. Operations below the
measured offload threshold stay local to avoid isolate-copy overhead. The
threshold is benchmarked and named in code, not inferred from a file count.

Drift uses a background database executor for all schema, query, migration, and
transaction work. UI and application providers observe `watch` streams instead
of taking one-time snapshots and manually guessing when to invalidate.
Database open failure is a typed state with an explicit reset-sync-data
recovery action.

### User initiation and background continuation

A network sync starts only when the user taps Sync, Refresh, Retry, or Resume.
The resulting operation receives a durable operation identifier and may
continue after the app moves to the background while the operating system
allows execution.

Background continuation does not authorize:

- periodic or scheduled sync;
- prefetch;
- a sync on app start, navigation, or connectivity change;
- automatic refresh of a completed repository; or
- creation of a new operation without a user action.

If the process or operating system stops an incomplete operation, the
application preserves a resumable checkpoint but does not silently restart
network traffic. The next foreground UI shows the interrupted operation and
requires the user to tap Resume. A resumed operation may again continue when
the app backgrounds. Cancellation removes the checkpoint and temporary bytes.

The application shows one global in-flight indicator and exposes progress,
pause or cancellation state outside the repo-sync screen. Platform background
APIs are used only to extend an existing user-started operation, never as a
recurring scheduler.

### Durable operation and cancellation

Every sync has one cancellation scope propagated through:

- default-branch lookup and tree or Contents discovery;
- every Dio request and retry delay;
- worker-isolate parse and diff jobs;
- each bounded download worker;
- streaming file writes, flushes, and hashes;
- filesystem cleanup; and
- database transaction boundaries.

The domain ports accept the cancellation abstraction; implementations must not
create an unconnected mutable token. Cancellation is idempotent. It prevents
new work, cancels active Dio requests, checks between stream chunks and file
entries, and waits for child tasks to acknowledge termination before exposing
a cancelled terminal state.

A new sync cannot overwrite the cancellation scope of an active one. Duplicate
requests for the same repository either attach to the existing operation or
return a typed `SyncAlreadyRunningFailure`; they never silently no-op.

Cancellation preserves the last committed repository snapshot. Staging files,
uncommitted database rows, and the active-operation marker are removed or
reconciled before the next run.

### Natural keys and database invariants

The repository natural key is:

```text
(provider, owner, repository, ref, subpath)
```

The file natural key is:

```text
(repository_id, normalized_relative_path)
```

Both are real database unique constraints and the upsert conflict targets use
those constraints. Provider, owner, and repository use their provider-defined
canonical case; refs remain case-sensitive; subpaths are normalized.
Foreign keys are enabled in `beforeOpen`, and `ON DELETE CASCADE` behavior is
tested. Every schema transition from a supported version has a seeded
migration test; destructive migration requires an explicit data-loss decision
and is not the default repair.

Repository `fileCount`, `status`, `lastSyncedAt`, and the committed generation
change together only after the filesystem generation is ready. A run in which
every file fails is failed, not partial. Per-file failures remain queryable and
retryable; the UI does not auto-dismiss them.

### Filesystem and database integrity

Each downloaded file is written to a unique temporary file in the destination
filesystem, streamed through the configured byte cap, flushed, closed, and
verified before rename. A temporary file is never eligible for the unchanged
file fast path.

Because SQLite and the filesystem cannot share one atomic transaction, sync
uses a generation journal:

1. validate the locator, paths, current generation, free space, and size
   budget;
2. write and verify changed files in a contained staging generation;
3. compute a manifest of additions, replacements, and removals;
4. persist the prepared journal and manifest;
5. promote the staging generation with same-filesystem atomic renames;
6. update repository and file rows in one drift transaction; and
7. mark the journal committed, then remove the previous generation and
   temporary data.

Startup reconciliation completes or rolls back any prepared journal based on
the verified generation and database marker. It never reports the new
`fileCount`, status, or timestamp while the old generation is still active.

Files removed upstream are deleted from the promoted mirror as well as from the
database. A failed or cancelled update leaves the previous complete generation
readable. The sync result reports added, updated, unchanged, removed, failed,
and total byte counts from committed outcomes rather than attempted work.

### GitHub discovery and truncated trees

GitHub remains the first provider. Recursive Trees discovery is the fast path.
When GitHub returns `truncated: true`, the same sync immediately falls back to
recursive Contents API traversal at the requested subpath. This is required
behavior and is not deferred.

The fallback:

- uses the same shared allow-list, authenticated Dio client, retry policy,
  timeouts, cancellation scope, entry and byte budgets, and path validator;
- paginates or walks directories with bounded concurrency;
- deduplicates paths before download;
- emits discovery progress and a truthful partial or typed limit result; and
- never treats a truncated tree as a complete remote snapshot, because doing
  so could delete undiscovered local files.

If both discovery strategies fail, the previous committed mirror remains
intact. The user receives the provider status and an actionable retry path.

### Metered connections, size, and disk space

Metered or cellular connectivity produces a warning, not a hard block. Before
downloads start, the coordinator calculates the best available aggregate size
from provider metadata and checks free space for the staging generation plus
the previous committed generation.

On a metered connection the confirmation states the estimated bytes and file
count. If GitHub does not provide enough size data, the UI states that the size
is unknown. The user may continue or cancel. A remembered preference may skip
the warning, but Settings must expose it and a single sync can still be
cancelled.

An unmetered network does not bypass file, aggregate, or free-space limits.
Connection classification failure is treated as unknown and shown honestly;
it is not mapped to offline and does not silently authorize a large transfer.

### PAT validation and lifecycle

Anonymous access remains the default. A PAT is optional and follows this
lifecycle:

1. the user enters a token in the repo-sync settings surface;
2. the application validates it through the allow-listed GitHub API before
   persistence;
3. the UI shows the authenticated account and the minimum required access,
   without showing the token or full authorization headers;
4. only a successfully validated token is written to the secure-storage
   reference defined by ADR-0017;
5. a sync request reads it once into a short-lived request session;
6. the request interceptor attaches it only to an allow-listed HTTPS host and
   removes it before any disallowed redirect; and
7. the in-memory session is discarded at operation completion or cancellation.

Validation distinguishes invalid credentials, insufficient repository access,
SSO authorization, rate limiting, offline state, secure-storage failure, and
GitHub service failure. A `401` invalidates the session and asks the user to
replace or clear the stored token; it does not retry indefinitely. A `403` is
classified from response headers rather than assumed to mean rate limiting.

Clearing the PAT requires confirmation and reports secure-storage deletion
failure. Removing the final synced repository does not silently claim the PAT
was deleted; the removal UI offers a separate confirmed credential-clear
choice. Fresh-install reconciliation removes an iOS Keychain token that
survived uninstall, as required by ADR-0017.

PAT values, authorization headers, repository-private paths, and access
handles are excluded from logs, breadcrumbs, traces, database rows, operation
journals, and error details.

### Path containment

Every remote or persisted path is untrusted. One shared path policy applies
before URL creation, filesystem access, database lookup, and deletion:

- percent-decode user-supplied URL fields to a fixed point with a bounded pass
  count, and reject input that remains ambiguously encoded;
- treat provider JSON paths as already decoded and never decode them a second
  time;
- reject empty owner and repository segments, `.` and `..`, separators, NUL,
  control and bidirectional-override characters, and absolute paths;
- allow `/` inside a ref only as validated ref structure, reject empty,
  `.` or `..` ref components, and encode the complete ref for its API position;
- reject empty, `.` and `..` remote path components, platform separators,
  NUL, control characters, and bidirectional-override characters;
- encode every accepted URL path segment at the point of URL construction;
- normalize remote relative paths to `/` without accepting a platform
  separator;
- join only below the resolved mirror or staging root;
- reject symlinks and verify existing parents by resolved filesystem identity;
- verify containment again immediately before write, rename, and recursive
  delete; and
- return a typed failure when a portable path cannot be decoded or contained.

Recursive deletion accepts a typed, previously validated mirror-generation
root rather than a raw string. The Application Support root, filesystem root,
home directory, cache root, unresolved environment variable, and glob are
never valid recursive-delete targets.

Redirects remain manual and capped. Each resolved redirect target is checked
against the allow-list before replay so the PAT cannot cross the trust
boundary.

### Timeouts, retries, and bounded work

The shared client has separate connect, send, receive-idle, and whole-operation
timeouts. Transient retries use capped exponential backoff with jitter, honor
`Retry-After`, and stop immediately on cancellation. Non-idempotent local
promotion is never retried as if it were a network request.

Discovery, download concurrency, per-file bytes, aggregate bytes, redirect
hops, response depth, response entries, and journal lifetime are named,
centralized, and tested. Exceeding a bound preserves the previous generation
and returns a typed, actionable result.

### Verification

Acceptance requires tests for:

- cancellation during discovery, retry delay, download, flush, worker parsing,
  and database commit;
- two simultaneous sync requests and provider-disposal cancellation;
- background, process-stop checkpoint, explicit resume, and cancel cleanup;
- two consecutive syncs proving natural-key upsert and no duplicate file rows;
- foreign-key cascade and every supported migration path;
- mid-download, mid-promotion, and post-promotion/pre-database crash recovery;
- upstream deletion on disk and in the database;
- all-files-failed classification and persistent partial-failure details;
- truncated Trees fallback, fallback cancellation, fallback limits, and a
  fallback failure that leaves the prior mirror intact;
- metered, unmetered, and unknown connectivity with known and unknown sizes;
- valid, invalid, insufficient-scope, SSO, expired, cleared, and
  secure-storage-failure PAT states;
- malicious owner, repository, ref, subpath, remote path, portable token,
  symlink, and recursive-delete inputs; and
- UI responsiveness while large JSON decoding, hashing, and drift work run.

Integration tests use a deterministic fake HTTP server or Dio adapter and a
real temporary filesystem. Tests do not depend on live GitHub state.

## Consequences

### Positive

- A failed, cancelled, or interrupted sync leaves a complete prior mirror
  instead of a mixed generation.
- Natural keys, foreign keys, and watch streams make database state coherent
  and observable.
- Cancellation reaches actual network and storage work.
- Async root-isolate I/O and targeted worker isolates match Flutter and Dio's
  execution model without freezing the UI.
- Large GitHub trees work through the already-promised Contents fallback.
- User-started work can survive ordinary backgrounding without authorizing
  scheduled traffic.
- Metered users retain control without losing the ability to sync.
- PAT and path handling have explicit end-to-end trust boundaries.

### Negative

- Generation staging temporarily requires space for old and new content.
- Journaling and startup reconciliation are more complex than in-place writes.
- Background execution remains subject to iOS and Android operating-system
  limits; the application cannot promise completion after termination.
- Contents fallback uses more API requests and can reach GitHub rate limits.
- Metered warnings add one decision point before some syncs.
- Worker-isolate thresholds and concurrency limits require benchmark
  maintenance.

## Alternatives considered

### Keep ADR-0012 and patch individual bugs

Rejected because storage integrity, execution placement, cancellation,
background continuation, and path containment are coupled invariants. Patching
them independently would leave contradictory architecture guidance.

### Run the entire sync in `compute()`

Rejected because Dio, plugin-backed secure storage, path-provider calls,
Riverpod state, cancellation tokens, and drift executors are not one sendable
object graph. Async root-isolate networking plus isolated CPU work addresses
the actual sources of blocking.

### Update files in place and wrap only database writes in a transaction

Rejected because a database transaction cannot roll back a truncated or
deleted filesystem entry. Same-filesystem staging plus a recovery journal is
required for cross-store convergence.

### Hard-fail every truncated GitHub tree

Rejected because ADR-0012 already identified a viable Contents fallback, and
silently limiting sync to small repositories contradicts the feature's stated
scope.

### Block sync on metered networks

Rejected because connectivity classification can be wrong and users may
deliberately accept the cost. A truthful size warning preserves user agency
while retaining all hard resource caps.

### Periodically refresh repositories in the background

Rejected because it violates the user-initiated network policy, creates
unexpected traffic, and widens privacy and battery impact. Only an explicitly
started, incomplete operation may continue in the background.
