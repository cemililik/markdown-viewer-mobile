import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';

/// Copies a folder-sourced markdown file into a cache slot and
/// returns the resulting filesystem path so the viewer pipeline can
/// read it with plain `dart:io`.
///
/// Concrete implementation lives in `data/services/` and handles the
/// platform details (iOS security-scope claim + NSData copy, Android
/// SAF `ContentResolver` copy). The abstraction here lets the
/// application-layer provider depend on a port instead of the
/// concrete class — see
/// [docs/standards/architecture-standards.md](../../../../../docs/standards/architecture-standards.md).
abstract class FolderFileMaterializer {
  /// Materializes the file at [sourcePath] (which lives under
  /// [folder]'s bookmarked tree) into the app cache and returns the
  /// cache path. Throws on any read error so the caller can surface
  /// a localized snackbar.
  Future<String> materialize({
    required LibraryFolder folder,
    required String sourcePath,
  });
}
