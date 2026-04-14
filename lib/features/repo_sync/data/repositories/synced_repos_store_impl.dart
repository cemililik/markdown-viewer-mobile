import 'dart:io';

import 'package:drift/drift.dart';
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

    if (existing != null) {
      final companion = SyncedReposCompanion(
        id: Value(existing.id),
        provider: Value(repo.provider),
        owner: Value(repo.owner),
        repo: Value(repo.repo),
        ref: Value(repo.ref),
        subPath: Value(repo.subPath),
        localRoot: Value(repo.localRoot),
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
        localRoot: repo.localRoot,
        lastSyncedAt: repo.lastSyncedAt.millisecondsSinceEpoch,
        fileCount: Value(repo.fileCount),
        status: Value(_statusToString(repo.status)),
      ),
    );
    return repo.copyWith(id: id);
  }

  @override
  Future<void> delete(int id) async {
    // Retrieve localRoot before deleting so we can wipe the directory.
    final rows = await _db.getAllRepos();
    final row = rows.where((r) => r.id == id).firstOrNull;
    await _db.deleteRepo(id);
    if (row != null) {
      final dir = Directory(row.localRoot);
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
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
      localPath: localPath,
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
  Future<void> deleteFilesForRepo(int repoId) => _db.deleteFilesForRepo(repoId);

  // ── Mapping helpers ──────────────────────────────────────────────────

  static SyncedRepo _rowToEntity(SyncedRepoRow row) => SyncedRepo(
    id: row.id,
    provider: row.provider,
    owner: row.owner,
    repo: row.repo,
    ref: row.ref,
    subPath: row.subPath,
    localRoot: row.localRoot,
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
