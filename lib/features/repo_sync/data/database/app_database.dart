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
}

// ── Connection factory ─────────────────────────────────────────────────────

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'markdown_viewer.db'));
    return NativeDatabase(file);
  });
}
