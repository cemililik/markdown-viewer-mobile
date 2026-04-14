import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';

/// A selectable "source" shown in the library drawer. Picking a
/// source swaps the library screen body between the recents view
/// and the tree view for one of the user's folders.
///
/// This is the single mental model the library screen runs on:
/// the drawer is the source picker, the body is the content of
/// whichever source is currently active. Recents is a first-class
/// source (not a special case) so future source types — synced
/// repositories, cloud mounts — slot into the same drawer list
/// without needing a redesign.
sealed class LibrarySource {
  const LibrarySource();
}

/// The default library source: the time-grouped recent documents
/// list with greeting, search, and pinned section. Shown on app
/// start so the user lands on the "where did I leave off?"
/// answer before they have to make any selections.
final class RecentsSource extends LibrarySource {
  const RecentsSource();
}

/// A user-added directory the library is browsing. Wraps the
/// existing [LibraryFolder] value type so the active-source
/// controller does not duplicate the identity or metadata the
/// folder list already persists.
final class FolderSource extends LibrarySource {
  const FolderSource(this.folder);

  final LibraryFolder folder;
}
