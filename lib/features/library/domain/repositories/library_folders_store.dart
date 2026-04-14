import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';

/// Persistence port for the user's library root directories.
///
/// `read` is synchronous so the home screen can hydrate the
/// folder explorer drawer on the very first frame without
/// waiting on a disk hop — see the matching pattern in
/// `RecentDocumentsStore` and `ReadingPositionStore`. `write`
/// is async because `SharedPreferences.setString` is.
abstract interface class LibraryFoldersStore {
  /// Returns every persisted [LibraryFolder]. Implementations
  /// must return an empty list (never throw) for a fresh install
  /// or when the underlying blob is corrupt.
  List<LibraryFolder> read();

  /// Replaces the stored list with [folders]. Implementations
  /// must persist the order they receive so the controller can
  /// own the canonical "most recent first" ordering rather than
  /// having to re-sort on every read.
  Future<void> write(List<LibraryFolder> folders);
}
