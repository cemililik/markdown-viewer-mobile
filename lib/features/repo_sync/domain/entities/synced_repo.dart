import 'package:freezed_annotation/freezed_annotation.dart';

part 'synced_repo.freezed.dart';

/// Sync health for a persisted [SyncedRepo].
enum SyncStatus {
  /// All files downloaded successfully on the last sync.
  ok,

  /// At least one file failed on the last sync; the rest are usable.
  partial,

  /// The last sync attempt failed entirely.
  failed,
}

/// A persisted record of a synced remote repository.
///
/// Maps 1-to-1 with a row in the `synced_repos` drift table.
/// [localRoot] is the absolute path on the device where all
/// downloaded files live; the directory structure mirrors the
/// remote sub-path so relative links between documents keep working.
@freezed
abstract class SyncedRepo with _$SyncedRepo {
  const factory SyncedRepo({
    required int id,

    /// Provider identifier, e.g. `'github'`.
    required String provider,

    /// Repository owner (user or organisation).
    required String owner,

    /// Repository name.
    required String repo,

    /// Branch, tag, or commit SHA that was synced.
    required String ref,

    /// Sub-path within the repo that was synced. Empty = root.
    @Default('') String subPath,

    /// Absolute path to the local mirror directory on this device.
    required String localRoot,

    /// When the last successful (or partial) sync completed.
    required DateTime lastSyncedAt,

    /// Number of files in the local mirror after the last sync.
    @Default(0) int fileCount,

    /// Health of the last sync run.
    @Default(SyncStatus.ok) SyncStatus status,
  }) = _SyncedRepo;

  const SyncedRepo._();

  /// Human-readable identifier shown in the UI, e.g. `owner/repo`.
  String get displayName => '$owner/$repo';

  /// `true` when the last sync left at least some files usable.
  bool get hasContent => fileCount > 0;
}
