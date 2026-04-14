import 'package:freezed_annotation/freezed_annotation.dart';

part 'remote_file.freezed.dart';

/// A single markdown file discovered on the remote provider and
/// ready for download.
///
/// [rawUrl] is pre-computed by [RepoSyncProvider.listFiles] so that
/// [RepoSyncProvider.downloadRaw] is provider-agnostic — it just
/// fetches [rawUrl] without needing to re-derive the URL schema.
@freezed
abstract class RemoteFile with _$RemoteFile {
  const factory RemoteFile({
    /// Path relative to the repository root, e.g. `docs/api/ref.md`.
    required String path,

    /// Git blob SHA used for change detection on re-sync.
    required String sha,

    /// File size in bytes (0 when not provided by the API).
    @Default(0) int size,

    /// Direct download URL for the raw file bytes.
    required String rawUrl,
  }) = _RemoteFile;
}
