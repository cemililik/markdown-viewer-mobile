import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:markdown_viewer/features/repo_sync/domain/entities/synced_repo.dart';

part 'sync_result.freezed.dart';

/// The outcome of a completed repository sync operation.
@freezed
abstract class SyncResult with _$SyncResult {
  const factory SyncResult({
    /// Total usable files after this sync (downloaded + skipped via SHA match).
    required int syncedCount,

    /// Files actually fetched from the network on this run.
    ///
    /// On a first sync this equals [syncedCount]. On subsequent syncs the
    /// difference [syncedCount] − [downloadedCount] reveals unchanged files
    /// that were skipped because their remote SHA matched the local copy.
    required int downloadedCount,

    /// Files that could not be downloaded (network errors, 404s).
    @Default(0) int failedCount,

    /// The persisted [SyncedRepo] record as written to the database.
    required SyncedRepo repo,
  }) = _SyncResult;

  const SyncResult._();

  /// `true` when at least one file could not be downloaded.
  bool get isPartial => failedCount > 0;

  /// Files skipped because their SHA matched the cached local copy.
  int get skippedCount => syncedCount - downloadedCount;

  /// `true` when some files were already up-to-date — signals a re-sync
  /// rather than a fresh clone.
  bool get isIncremental => skippedCount > 0;
}
