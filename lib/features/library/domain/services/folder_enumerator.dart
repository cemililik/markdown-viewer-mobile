import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';

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

/// Pure-domain port for listing the markdown files and
/// subdirectories of a [LibraryFolder].
///
/// The contract is intentionally narrow:
///
/// - Only one level is enumerated per [enumerate] call. Recursive
///   walks live on a separate [enumerateRecursive] method because
///   they are strictly used by the folder-body search view and
///   are much more expensive.
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
/// Both methods take a [LibraryFolder] rather than a plain path
/// so the implementation can route by the optional
/// `bookmark` field: on iOS, bookmarked folders go through the
/// native `LibraryFoldersChannel`; everywhere else, plain
/// `dart:io` is used.
abstract interface class FolderEnumerator {
  /// Lists the immediate children of [folder]. Tests may pass an
  /// explicit [subPath] to enumerate a sub-directory of the root
  /// without re-asking the user to re-pick; production callers
  /// walk the tree by calling `enumerate` on a [LibraryFolder]
  /// constructed from the sub-path they want to drill into.
  Future<List<FolderEntry>> enumerate(LibraryFolder folder, {String? subPath});

  /// Walks [folder] recursively and returns a flat list of every
  /// markdown file underneath it. Hidden dot-directories are
  /// skipped so `.git` / `.cache`-style noise does not drag into
  /// the search results. Used by the library folder body when
  /// the search field is non-empty.
  Future<List<FolderFileEntry>> enumerateRecursive(LibraryFolder folder);
}
