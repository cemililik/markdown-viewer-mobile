/// A single immediate child of a library folder, returned by the
/// folder enumerator when the drawer expands a directory.
///
/// The drawer only needs to know whether each child is a leaf
/// (a markdown file the user can tap to open) or a branch (a
/// subfolder the user can expand for one more level). Both kinds
/// share the same path + display-name shape, so a single sealed
/// hierarchy with a discriminator field keeps the call sites
/// simple — the alternative (two parallel lists) makes ordering
/// and rendering harder.
sealed class FolderEntry {
  const FolderEntry({required this.path, required this.name});

  /// Absolute path on disk. Used as the identity of the entry
  /// (drawer uses it as the `Key` for animated reorder) and
  /// passed straight to the viewer route when the user taps a
  /// markdown file.
  final String path;

  /// Display name shown in the drawer tile — the basename of the
  /// path with the directory separator stripped.
  final String name;
}

/// A markdown file under a library folder. Tapping the
/// corresponding drawer tile pushes `/viewer?path=…` and the
/// recent documents controller picks the open up through the
/// existing `ref.listen` funnel — no extra wiring needed.
final class FolderFileEntry extends FolderEntry {
  const FolderFileEntry({required super.path, required super.name});
}

/// A subdirectory under a library folder. The drawer renders this
/// as an `ExpansionTile` whose children are loaded lazily through
/// another `enumerate` call when the user expands it for the
/// first time, so a deep tree never gets walked eagerly.
final class FolderSubdirEntry extends FolderEntry {
  const FolderSubdirEntry({required super.path, required super.name});
}

/// Pure-domain port for listing the immediate `.md` files and
/// subdirectories of a single folder.
///
/// The contract is intentionally narrow:
///
/// - Only one level is enumerated per call. Recursive walks are
///   the caller's responsibility, which lets the drawer expand
///   each subfolder lazily without forcing the implementation to
///   know about the UI's expand state.
/// - Hidden entries (`.git`, `.DS_Store`, anything starting with
///   `.`) are filtered out so the drawer is not noise.
/// - Subdirectories are returned regardless of their contents —
///   the drawer needs them to render the expansion tile, and the
///   enumerator should not load every child of every folder just
///   to decide whether to show the parent.
/// - File entries are filtered to `*.md` and `*.markdown` (case
///   insensitive). Other file types stay invisible.
/// - Entries are sorted alphabetically with subdirectories first
///   so the drawer reads top-down by hierarchy depth.
///
/// The data layer's implementation lives in
/// `data/services/folder_enumerator_impl.dart` and is the only
/// place in the library feature that touches `dart:io`.
abstract interface class FolderEnumerator {
  /// Returns the immediate children of [folderPath] as a flat
  /// list of [FolderEntry] values, throwing on any I/O failure
  /// so the drawer can surface a localized inline error tile
  /// without falling back to an empty list (which would be
  /// indistinguishable from a legitimately empty folder).
  Future<List<FolderEntry>> enumerate(String folderPath);
}
