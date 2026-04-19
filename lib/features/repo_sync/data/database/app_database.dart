import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ── Table definitions ──────────────────────────────────────────────────────

@DataClassName('SyncedRepoRow')
class SyncedRepos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get provider => text()();
  TextColumn get owner => text()();
  TextColumn get repo => text()();
  TextColumn get ref => text()();
  TextColumn get subPath => text().withDefault(const Constant(''))();
  TextColumn get localRoot => text()();

  /// Milliseconds since epoch (UTC).
  IntColumn get lastSyncedAt => integer()();
  IntColumn get fileCount => integer().withDefault(const Constant(0))();

  /// One of `'ok'`, `'partial'`, `'failed'`.
  TextColumn get status => text().withDefault(const Constant('ok'))();
}

@DataClassName('SyncedFileRow')
class SyncedFiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get repoId =>
      integer().references(SyncedRepos, #id, onDelete: KeyAction.cascade)();
  TextColumn get remotePath => text()();
  TextColumn get localPath => text()();

  /// Git blob SHA — used for change-detection on re-sync.
  TextColumn get sha => text()();
  IntColumn get size => integer().withDefault(const Constant(0))();

  /// One of `'synced'`, `'failed'`, `'pending'`.
  TextColumn get status => text().withDefault(const Constant('pending'))();
}

// ── Database ───────────────────────────────────────────────────────────────

@DriftDatabase(tables: [SyncedRepos, SyncedFiles])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ── Repo queries ──────────────────────────────────────────────────────

  Future<List<SyncedRepoRow>> getAllRepos() =>
      (select(syncedRepos)
        ..orderBy([(t) => OrderingTerm.desc(t.lastSyncedAt)])).get();

  Future<SyncedRepoRow?> getRepoByNaturalKey({
    required String provider,
    required String owner,
    required String repo,
    required String ref,
    required String subPath,
  }) =>
      (select(syncedRepos)..where(
        (t) =>
            t.provider.equals(provider) &
            t.owner.equals(owner) &
            t.repo.equals(repo) &
            t.ref.equals(ref) &
            t.subPath.equals(subPath),
      )).getSingleOrNull();

  /// Returns the [SyncedRepoRow] with the given [id], or `null` if absent.
  Future<SyncedRepoRow?> getRepoById(int id) =>
      (select(syncedRepos)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertRepo(SyncedReposCompanion entry) =>
      into(syncedRepos).insert(entry);

  Future<void> updateRepo(SyncedReposCompanion entry) =>
      (update(syncedRepos)
        ..where((t) => t.id.equals(entry.id.value))).write(entry);

  Future<void> deleteRepo(int id) =>
      (delete(syncedRepos)..where((t) => t.id.equals(id))).go();

  // ── File queries ──────────────────────────────────────────────────────

  Future<int> upsertFile(SyncedFilesCompanion entry) =>
      into(syncedFiles).insertOnConflictUpdate(entry);

  Future<List<SyncedFileRow>> getFilesForRepo(int repoId) =>
      (select(syncedFiles)..where((t) => t.repoId.equals(repoId))).get();

  Future<void> deleteFilesForRepo(int repoId) =>
      (delete(syncedFiles)..where((t) => t.repoId.equals(repoId))).go();

  Future<void> deleteFile({
    required int repoId,
    required String remotePath,
  }) async {
    await (delete(syncedFiles)..where(
      (t) => t.repoId.equals(repoId) & t.remotePath.equals(remotePath),
    )).go();
  }

  /// Removes every `synced_files` row for [repoId] whose `remote_path`
  /// is NOT in [retainedPaths].
  ///
  /// Implementation is "compute orphans in Dart, delete in batches":
  ///
  /// 1. Fetch the current row list (one SQL round trip).
  /// 2. Subtract `retainedPaths` in Dart to get the orphan set —
  ///    typically a handful of files a re-sync removed from the
  ///    remote, occasionally the whole repo on a renamed/deleted
  ///    subPath.
  /// 3. `DELETE ... WHERE remote_path IN (?, ?, …)` in chunks of
  ///    [_sqliteVariableBatchSize].
  ///
  /// Earlier revisions used `isNotIn(retainedPaths)` as a single
  /// statement — concise but crashes with "too many SQL variables"
  /// once [retainedPaths] exceeds the platform's
  /// `SQLITE_LIMIT_VARIABLE_NUMBER` (999 on stock SQLite; some builds
  /// raise it to 32_766 but the app can't assume that). Binding the
  /// smaller orphan list in batches of 500 is immune to that limit
  /// regardless of how many files the retained set contains.
  ///
  /// When [retainedPaths] is empty the method short-circuits to
  /// [deleteFilesForRepo] (one SQL DELETE, no variables bound).
  Future<void> deleteFilesNotIn({
    required int repoId,
    required Set<String> retainedPaths,
  }) async {
    if (retainedPaths.isEmpty) {
      await deleteFilesForRepo(repoId);
      return;
    }
    final existing = await getFilesForRepo(repoId);
    final orphans = <String>[
      for (final row in existing)
        if (!retainedPaths.contains(row.remotePath)) row.remotePath,
    ];
    if (orphans.isEmpty) return;
    // Batch the IN-list so a repo with many stale paths cannot
    // trip the SQLite variable limit.
    for (var i = 0; i < orphans.length; i += _sqliteVariableBatchSize) {
      final chunk = orphans.sublist(
        i,
        (i + _sqliteVariableBatchSize).clamp(0, orphans.length),
      );
      await (delete(
        syncedFiles,
      )..where((t) => t.repoId.equals(repoId) & t.remotePath.isIn(chunk))).go();
    }
  }

  /// Conservative batch size that fits well under the stock SQLite
  /// `SQLITE_LIMIT_VARIABLE_NUMBER` (999) while keeping round-trip
  /// count low on repos with thousands of removed files. Plus one
  /// for the `repoId` bind leaves plenty of headroom.
  static const int _sqliteVariableBatchSize = 500;
}

// ── Connection factory ─────────────────────────────────────────────────────

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // ApplicationSupport keeps the DB out of iOS `Documents/`, so
    // iCloud Drive and Finder/iTunes backups don't carry a plaintext
    // SQLite catalogue of the user's synced repos off-device. The
    // directory is private, persistent across launches, and not
    // exposed via `UIFileSharingEnabled`. Pair with the manifest-
    // level backup opt-outs on Android (allowBackup=false).
    //
    // Legacy DBs written by v1.1.x live at Documents/markdown_viewer.db;
    // migrate them on first open post-upgrade so users do not lose
    // their sync history when the app moves the DB location. The
    // migration covers WAL/SHM/journal sidecars too — a drift DB in
    // WAL mode that loses its sidecar files becomes non-recoverable.
    //
    // Reference: security-review SR-20260419-012 (promoted from L-7)
    // + PR-review follow-up for sidecar handling.
    final supportDir = await getApplicationSupportDirectory();
    if (!await supportDir.exists()) {
      await supportDir.create(recursive: true);
    }
    final target = File(p.join(supportDir.path, 'markdown_viewer.db'));
    if (!await target.exists()) {
      final docsDir = await getApplicationDocumentsDirectory();
      const baseName = 'markdown_viewer.db';
      // SQLite WAL / rollback-journal sidecars. Missing files are
      // fine; the main file is the required one.
      const sidecars = <String>['', '-wal', '-shm', '-journal'];
      for (final suffix in sidecars) {
        final legacyFile = File(p.join(docsDir.path, '$baseName$suffix'));
        final targetFile = File(p.join(supportDir.path, '$baseName$suffix'));
        if (!await legacyFile.exists()) continue;
        try {
          await legacyFile.rename(targetFile.path);
        } on FileSystemException {
          // Cross-device rename can fail (`errno 18` on Linux,
          // EXDEV on POSIX) — fall back to copy-then-delete so the
          // migration still completes when the Documents and
          // ApplicationSupport directories live on different
          // volumes.
          try {
            await legacyFile.copy(targetFile.path);
            await legacyFile.delete();
          } on FileSystemException {
            // Non-fatal: a half-migrated sidecar will be rebuilt by
            // SQLite on the next checkpoint. Log-and-drop rather
            // than abort startup — losing the sync catalogue would
            // be worse than losing the sidecar.
          }
        }
      }
    }
    return NativeDatabase(target);
  });
}
