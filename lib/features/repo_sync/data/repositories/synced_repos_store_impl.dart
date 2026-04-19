import 'dart:io';

import 'package:drift/drift.dart';
import 'package:markdown_viewer/core/path/sandbox_path.dart';
import 'package:markdown_viewer/features/repo_sync/data/database/app_database.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';
import 'package:markdown_viewer/features/repo_sync/domain/repositories/synced_repos_store.dart';

/// Drift-backed implementation of [SyncedReposStore].
class SyncedReposStoreImpl implements SyncedReposStore {
  const SyncedReposStoreImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<SyncedRepo>> readAll() async {
    final rows = await _db.getAllRepos();
    return rows.map(_rowToEntity).toList();
  }

  @override
  Future<SyncedRepo> upsert(SyncedRepo repo) async {
    final existing = await _db.getRepoByNaturalKey(
      provider: repo.provider,
      owner: repo.owner,
      repo: repo.repo,
      ref: repo.ref,
      subPath: repo.subPath,
    );

    // Persist the repo's localRoot in portable `sandbox:docs:...` form
    // so a container-UUID change (iOS dev reinstall, user uninstall +
    // reinstall, factory reset restored from backup) does not strand
    // the synced files — the next read resolves the token against the
    // CURRENT container. App Store updates preserve the UUID so
    // production users never hit this, but the indirection costs
    // nothing and keeps dev-build state usable across fresh installs.
    final portableLocalRoot = SandboxPath.toPortable(repo.localRoot);
    if (existing != null) {
      final companion = SyncedReposCompanion(
        id: Value(existing.id),
        provider: Value(repo.provider),
        owner: Value(repo.owner),
        repo: Value(repo.repo),
        ref: Value(repo.ref),
        subPath: Value(repo.subPath),
        localRoot: Value(portableLocalRoot),
        lastSyncedAt: Value(repo.lastSyncedAt.millisecondsSinceEpoch),
        fileCount: Value(repo.fileCount),
        status: Value(_statusToString(repo.status)),
      );
      await _db.updateRepo(companion);
      return repo.copyWith(id: existing.id);
    }

    final id = await _db.insertRepo(
      SyncedReposCompanion.insert(
        provider: repo.provider,
        owner: repo.owner,
        repo: repo.repo,
        ref: repo.ref,
        subPath: Value(repo.subPath),
        localRoot: portableLocalRoot,
        lastSyncedAt: repo.lastSyncedAt.millisecondsSinceEpoch,
        fileCount: Value(repo.fileCount),
        status: Value(_statusToString(repo.status)),
      ),
    );
    return repo.copyWith(id: id);
  }

  @override
  Future<void> delete(int id) async {
    // Retrieve localRoot BEFORE touching the DB so we still know
    // which directory to wipe. Delete the directory first and the DB
    // row second so that a directory-delete failure (iOS sandbox
    // permission hiccup, Android content:// URI transient failure,
    // etc.) leaves the DB row intact — the user can retry from the
    // UI and the bookkeeping still reflects reality. The reverse
    // order would orphan the on-disk files with no DB pointer to
    // find them again.
    final row = await _db.getRepoById(id);
    if (row != null) {
      final dir = Directory(SandboxPath.fromPortable(row.localRoot));
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
    await _db.deleteRepo(id);
  }

  @override
  Future<void> upsertFile({
    required int repoId,
    required String remotePath,
    required String localPath,
    required String sha,
    required int size,
    required String status,
  }) => _db.upsertFile(
    SyncedFilesCompanion.insert(
      repoId: repoId,
      remotePath: remotePath,
      // Per-file paths share the localRoot's portable-token treatment
      // so `File(localPath)` resolves against the current container
      // after a fresh install. See `upsert` above for the rationale.
      localPath: SandboxPath.toPortable(localPath),
      sha: sha,
      size: Value(size),
      status: Value(status),
    ),
  );

  @override
  Future<Map<String, String>> knownShas(int repoId) async {
    final files = await _db.getFilesForRepo(repoId);
    return {
      for (final f in files)
        if (f.status == 'synced') f.remotePath: f.sha,
    };
  }

  @override
  Future<SyncedRepo?> findByNaturalKey({
    required String provider,
    required String owner,
    required String repo,
    required String ref,
    required String subPath,
  }) async {
    final row = await _db.getRepoByNaturalKey(
      provider: provider,
      owner: owner,
      repo: repo,
      ref: ref,
      subPath: subPath,
    );
    return row == null ? null : _rowToEntity(row);
  }

  @override
  Future<void> deleteFilesForRepo(int repoId) => _db.deleteFilesForRepo(repoId);

  @override
  Future<String?> readEtag(int repoId) async {
    final row = await _db.getRepoById(repoId);
    return row?.etag;
  }

  @override
  Future<void> writeEtag(int repoId, String? etag) async {
    await (_db.update(_db.syncedRepos)..where(
      (t) => t.id.equals(repoId),
    )).write(SyncedReposCompanion(etag: Value(etag)));
  }

  @override
  Future<void> deleteFilesNotIn(int repoId, Set<String> retainedPaths) {
    // Single batched SQL statement (`DELETE … WHERE … NOT IN`)
    // handled by the drift DAO. The previous per-row loop issued one
    // round-trip per orphan, which was O(n) on the number of files
    // the user no longer has.
    return _db.deleteFilesNotIn(repoId: repoId, retainedPaths: retainedPaths);
  }

  // ── Mapping helpers ──────────────────────────────────────────────────

  static SyncedRepo _rowToEntity(SyncedRepoRow row) => SyncedRepo(
    id: row.id,
    provider: row.provider,
    owner: row.owner,
    repo: row.repo,
    ref: row.ref,
    subPath: row.subPath,
    // Resolve any `sandbox:docs:<relative>` token written by an
    // earlier session against the current container's absolute prefix
    // so callers (library body, viewer) can feed the path straight to
    // `File(...)` / `Directory(...)`. Legacy absolute paths left over
    // from pre-portable sessions passthrough unchanged.
    localRoot: SandboxPath.fromPortable(row.localRoot),
    lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(
      row.lastSyncedAt,
      isUtc: true,
    ),
    fileCount: row.fileCount,
    status: _statusFromString(row.status),
  );

  static SyncStatus _statusFromString(String s) => switch (s) {
    'partial' => SyncStatus.partial,
    'failed' => SyncStatus.failed,
    _ => SyncStatus.ok,
  };

  static String _statusToString(SyncStatus s) => switch (s) {
    SyncStatus.ok => 'ok',
    SyncStatus.partial => 'partial',
    SyncStatus.failed => 'failed',
  };
}
