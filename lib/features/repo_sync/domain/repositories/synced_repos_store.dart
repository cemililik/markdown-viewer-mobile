import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';

/// Persistence port for synced repository records.
///
/// The data layer provides a drift-backed implementation; tests
/// use a hand-written fake. Every method is async because all
/// implementations hit a database.
abstract interface class SyncedReposStore {
  /// Returns all persisted synced repositories, most recently
  /// synced first.
  Future<List<SyncedRepo>> readAll();

  /// Inserts or updates the record for [repo] keyed on
  /// (provider, owner, repo, ref, subPath). Returns the persisted
  /// entity with its database-assigned [SyncedRepo.id].
  Future<SyncedRepo> upsert(SyncedRepo repo);

  /// Finds an existing repo by its natural key so the application
  /// layer can decide whether a sync is a first run or an update
  /// without iterating [readAll]. Implementations resolve the lookup
  /// via a direct database-backed query rather than a full-list scan
  /// — the tuple `(provider, owner, repo, ref, subPath)` matches the
  /// same natural-key contract used by [upsert]. Returns `null` when
  /// no record matches.
  Future<SyncedRepo?> findByNaturalKey({
    required String provider,
    required String owner,
    required String repo,
    required String ref,
    required String subPath,
  });

  /// Permanently removes the record with [id] and all associated
  /// per-file rows. Also deletes the local mirror directory.
  Future<void> delete(int id);

  /// Records a per-file sync outcome. Used for progress tracking
  /// and SHA-based change detection on re-sync.
  Future<void> upsertFile({
    required int repoId,
    required String remotePath,
    required String localPath,
    required String sha,
    required int size,
    required String status,
  });

  /// Returns a map of remotePath → sha for all files belonging
  /// to [repoId]. Used to skip unchanged files on re-sync.
  Future<Map<String, String>> knownShas(int repoId);

  /// Removes all per-file rows for [repoId]. Called when the repo
  /// itself is being deleted; use [deleteFilesNotIn] for incremental
  /// cleanup during a sync to preserve metadata for files that
  /// might still be unchanged on disk.
  Future<void> deleteFilesForRepo(int repoId);

  /// Removes file rows for [repoId] whose `remotePath` is not in
  /// [retainedPaths]. Called at the end of a successful sync to
  /// evict entries for files that were removed from the remote
  /// while preserving metadata (SHA, localPath) for everything
  /// that was just observed.
  ///
  /// Skipping this call on cancellation is deliberate: the pre-sync
  /// [knownShas] map stays valid so a subsequent re-sync can still
  /// detect unchanged files on disk and skip them.
  Future<void> deleteFilesNotIn(int repoId, Set<String> retainedPaths);

  /// Returns the most recent Git Trees API `ETag` captured for
  /// [repoId], or `null` when the repo has never been synced under
  /// the etag-aware code path. The sync notifier sends this value
  /// back as `If-None-Match` so an unchanged tree short-circuits
  /// on a 304 response instead of re-downloading the full listing.
  /// Reference: performance-review PR-20260419-016.
  Future<String?> readEtag(int repoId);

  /// Persists the Git Trees API `ETag` for [repoId]. Passing `null`
  /// clears a stale value (e.g. after a ref change that invalidated
  /// the cached tree). No-op when [repoId] does not exist.
  Future<void> writeEtag(int repoId, String? etag);
}
