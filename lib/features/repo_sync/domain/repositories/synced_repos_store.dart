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

  /// Removes all per-file rows for [repoId]. Called at the start
  /// of a fresh sync to clear stale entries before re-populating.
  Future<void> deleteFilesForRepo(int repoId);
}
