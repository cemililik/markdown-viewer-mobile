# ADR-0017: Local content storage, cache lifecycle, and portable restore

- **Status**: Accepted
- **Date**: 2026-07-30
- **Deciders**: Cemil Ilık
- **Owner**: Cemil Ilık
- **Revisit date**: 2026-10-30
- **Depends on**:
  [ADR-0016](0016-platform-channel-contract-and-native-io.md)
- **Related**: [ADR-0007](0007-local-storage.md),
  [ADR-0011](0011-network-access-policy.md)

This record proposes a complete location, backup, retention, deletion, and
restore policy for local application data.

## Context

The application stores several classes of local data with different
durability and privacy needs: repository mirrors, externally opened file
copies, folder materializations, rendered assets, recents, reading positions,
source grants, settings, and a GitHub Personal Access Token (PAT).

The existing persistence ADR selects storage technologies but does not define
where every data class lives, whether it is backed up, how long it is retained,
or what each clear and remove action deletes. On iOS, synced repository
content currently lives in the user-visible, iCloud-backed Documents
directory. The mirror can contain private company documentation in plaintext,
while its catalogue is stored elsewhere. Cache and reading-position stores
also lack one coherent retention and deletion contract.

Storage paths must additionally survive an iOS container UUID change and a
device restore. Absolute sandbox paths cannot be durable identifiers, and a
restored catalogue must not pretend that backup-excluded content is present.

## Decision

### Data classes and locations

The following inventory is normative:

| Data class | Location | Backup | Retention and deletion |
|------------|----------|--------|------------------------|
| Sync mirror | Support `synced_repos/` | Excluded | Until repo removal; generation replacement |
| Folder copies | Platform cache `library_files/` | Excluded | 50 MiB LRU; clear with source |
| File-open intake | Platform cache `file_open/` | Excluded | Seven days or 50 MiB |
| Persistent render cache | Platform cache `rendered/` | Excluded | Versioned key and byte-budgeted LRU |
| Drift database and source catalogue | Application Support | Included | Until explicit reset or owning source removal |
| Recents and reading positions | Application Support database | Included | Bounded as described below; user-clearable |
| Preferences | Platform preferences store | Platform default | Until reset |
| Access handles | Protected platform store | Platform default | Until removal, reset, or invalidation |
| GitHub PAT | Platform secure storage | Secure-store policy | Until confirmed clear or invalidation |
| User exports | User-selected destination | User-controlled | App retains no authority after export |

“Platform cache” means `Context.cacheDir` on Android and `Library/Caches`
(`NSCachesDirectory`) on iOS. Each named value is an application-owned child
of that root; “Application Cache” is not a separate storage class. “Support”
means the platform Application Support or files root selected by
`path_provider`, never the user-visible iOS Documents directory.

No plaintext document copy is written to a general preferences store, a
database blob, logs, analytics, or Sentry.

Application Support is private placement, not a backup guarantee. On iOS the
mirror root must have `NSURLIsExcludedFromBackupKey` set when it is created and
verified on every application startup. Startup reconciliation recreates a
missing root, reapplies the attribute, and fails visibly if the effective
attribute cannot be verified. The implementation uses the versioned
`storage_policy` boundary from
[ADR-0016](0016-platform-channel-contract-and-native-io.md).

### iOS Files exposure

`UIFileSharingEnabled` is false and
`LSSupportsOpeningDocumentsInPlace` does not expose the application sandbox.
The application has no shared Documents directory. Users open inputs and
choose export destinations through system pickers; sync mirrors, caches,
catalogues, and credentials never appear as app-owned Files locations.

If a future feature needs a Files-visible managed folder, it requires a new
ADR with an explicit threat model, backup policy, and user-facing deletion
contract.

### Documents-to-Application-Support migration

The first compatible startup performs an idempotent migration from the legacy
iOS `Documents/synced_repos/` root:

1. create the Application Support mirror root and verify backup exclusion;
2. inventory and validate every legacy path against the legacy root;
3. move each repository into a staging directory on the destination
   filesystem, preserving no symlinks or paths that escape the root;
4. verify the staged file count and hashes where recorded;
5. atomically promote each staged repository;
6. rewrite persisted locations to portable identities in one database
   transaction; and
7. delete a legacy repository only after its destination and catalogue commit
   are verified.

An interruption resumes from a migration journal. Name collisions, invalid
paths, insufficient disk space, and permission failures preserve the legacy
copy and surface a recoverable error. The migration never chooses one copy
silently. After all repositories migrate, it removes the empty legacy root
and keeps Files sharing disabled.

Recents and reading positions are keyed by portable document identity, not an
absolute path, so they continue to resolve after relocation. Existing absolute
records are migrated before the legacy mirror is removed.

### Portable identity and restore

Persisted content identity is a versioned logical value:

```text
source kind + stable source identity + normalized relative document path
```

For a synced document, the source identity contains provider, owner,
repository, ref, and selected subpath. For a folder source, it contains the
source's locally generated stable identifier and the relative path. The opaque
access handle is stored separately and may be refreshed without changing
document identity. Cache locations and absolute sandbox roots are resolved at
runtime and are never durable identity.

Portable tokens must round-trip after an iOS container UUID change. Decoding
an unknown version, root kind, absolute path, traversal segment, or malformed
token returns a typed failure; the token is never passed through as a path.

On device restore:

- catalogues, recents, and reading positions may restore;
- repository mirrors and caches are expected to be absent;
- a missing mirror is shown as `needsSync` and is downloaded only after an
  explicit user action;
- an access handle that no longer resolves is shown as `needsAuthorization`
  and requires the system picker;
- a recent whose source cannot currently resolve remains unavailable rather
  than opening an unrelated path; and
- restored metadata is reconciled before the library is presented.

Portable restore excludes credentials. A PAT is never serialized into a
portable token, database, preferences, export, or application backup.

### Cache lifecycle

All caches have a central, testable policy and a startup reconciliation pass.
Automatic pruning uses oldest successful access first and is atomic with
metadata cleanup. It never leaves a recent entry pointing only at deleted
bytes.

A pinned recent is protected from automatic cache eviction. If its current
copy is missing, the app rematerializes it from an authorized source when the
user opens it. When no authorized source exists, the UI reports that fact and
offers source reauthorization; it does not fabricate success.

Source removal is a confirmed fan-out operation:

- delete all cached plaintext derived from the source;
- prune recents for the source, including pinned entries;
- clear its reading positions;
- release the Android persistable URI grant or remove the iOS access-handle
  reference;
- remove the source catalogue record; and
- for a synced repository, delete the contained mirror and its sync rows.

Deletion is idempotent and path-contained. A failure leaves a recoverable
removal state and is retried during startup reconciliation. The UI does not
report complete removal while plaintext or a persisted grant remains.

Settings provides distinct, confirmed actions:

| Action | Effect |
|--------|--------|
| Clear caches | Deletes all caches; keeps sources and positions; prunes unusable recents atomically |
| Clear reading history | Clears recents and all reading positions; preserves sources, mirrors, and the PAT |
| Reset app data | Clears non-credential app data; separately offers to clear the PAT |
| Clear GitHub credential | Clears only the PAT after confirmation |

No button called “clear cache,” “remove source,” or “reset” may leave data that
its user-facing confirmation says will be deleted.

### Reading-position retention

Reading positions live in structured storage rather than one unbounded
preference key per document. They use the portable document identity, include
`savedAt`, and have these rules:

- retain at most 500 positions;
- evict the oldest `savedAt` position when the cap is exceeded;
- clear a position when its source is removed;
- support `clearForSource` and `clearAll`;
- self-heal a corrupt record by removing it after logging sanitized context;
  and
- keep a position when only derived cache bytes are cleared.

The Settings reset and Clear reading history actions call `clearAll`.
Migration from hashed legacy keys may retain only records that can be mapped
without reconstructing or logging a private absolute path.

### PAT separation

The GitHub PAT is a credential, not application content:

- the secret exists only in platform secure storage under a versioned,
  repo-sync-specific key;
- application state and the database may store only an opaque credential
  reference and non-secret validation metadata;
- reads return the credential to the smallest request scope and do not retain
  it in a long-lived controller;
- secure-storage reads, writes, and deletes use explicit Android encryption
  and iOS accessibility options;
- clear is confirmed and its failure is surfaced rather than represented as
  success; and
- a fresh-install marker outside the iOS Keychain detects uninstall/reinstall
  and deletes a surviving stale PAT before repo sync can use it.

PAT validation, authorization failure, and request-session lifetime are
governed by [ADR-0019](0019-repository-sync-execution-and-integrity.md).

### Verification

Implementation must include:

- location and backup-attribute tests using injected platform roots;
- migration tests for clean, interrupted, collision, corrupt, and
  insufficient-space cases;
- a native iOS test proving the exclusion attribute is reapplied after the
  mirror directory is deleted and recreated;
- portable-token round-trip and malicious-token tables;
- cache budget, pinned entry, source-removal fan-out, and startup
  reconciliation tests;
- reading-position cap, clear-for-source, clear-all, corruption, and
  relocation tests; and
- a fresh-install test proving a surviving iOS Keychain PAT is removed.

## Consequences

### Positive

- Synced private documentation is no longer visible in Files or included in
  iCloud backup.
- Every local data class gains an explicit location, retention policy, and
  deletion path.
- Container relocation and device restore no longer depend on stale absolute
  paths.
- Source removal revokes access and removes derived plaintext as one
  user-visible operation.
- Reading history is bounded and user-clearable, while ordinary cache clearing
  does not lose the reader's place.
- Credentials are isolated from portable application content.

### Negative

- The iOS relocation requires an idempotent migration and recovery journal.
- Startup performs backup-attribute and storage reconciliation work.
- Portable identity and source-aware deletion require database schema changes.
- Protecting pinned entries can reduce the space available to the automatic
  cache until the user unpins or explicitly clears data.
- Restored catalogues may show unavailable content until the user authorizes or
  syncs it again.

## Alternatives considered

### Keep synced repositories in Documents and only set backup exclusion

Rejected because backup exclusion does not remove Files exposure, and the
Documents location communicates user-managed files that the application
actually owns and mutates.

### Move the mirror to Application Support without excluding it from backup

Rejected because Application Support is not inherently excluded from iCloud
backup. Private mirrored content would remain an unnecessary backup payload.

### Exclude all Application Support data from backup

Rejected because catalogues, portable reading positions, and preferences are
small, user-meaningful state. Only reconstructible or plaintext content roots
are excluded.

### Clear reading positions whenever cache bytes are evicted

Rejected because reading position belongs to a stable document identity, not
to a transient materialization. It is cleared by history controls or source
removal instead.

### Store the PAT in the sync database

Rejected because a database backup or diagnostic copy would then contain a
live credential, and database lifecycle is not credential lifecycle.
