import 'dart:io';

import 'package:markdown_viewer/features/library/domain/services/folder_enumerator.dart';
import 'package:path/path.dart' as p;

/// `dart:io`-backed [FolderEnumerator].
///
/// This is the only place inside the library feature that
/// touches the filesystem — every other layer goes through the
/// abstract port. Keeping the I/O concentrated here means the
/// drawer widget can be widget-tested with a fake enumerator
/// that yields a deterministic tree from in-memory data.
class FolderEnumeratorImpl implements FolderEnumerator {
  const FolderEnumeratorImpl();

  @override
  Future<List<FolderEntry>> enumerate(String folderPath) async {
    final directory = Directory(folderPath);
    final children = await directory.list(followLinks: false).toList();

    final files = <FolderFileEntry>[];
    final subdirs = <FolderSubdirEntry>[];

    for (final child in children) {
      final name = p.basename(child.path);
      // Hide dot-files and dot-folders so a `.git` checkout or
      // macOS `.DS_Store` does not pollute the drawer with noise
      // the user never asked to see.
      if (name.startsWith('.')) continue;

      if (child is Directory) {
        subdirs.add(FolderSubdirEntry(path: child.path, name: name));
      } else if (child is File) {
        final lower = name.toLowerCase();
        if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
          files.add(FolderFileEntry(path: child.path, name: name));
        }
      }
    }

    // Sort each bucket alphabetically (case-insensitive) so the
    // drawer reads predictably regardless of filesystem order,
    // which on macOS is creation order rather than alphabetical.
    int byName(FolderEntry a, FolderEntry b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    subdirs.sort(byName);
    files.sort(byName);

    return <FolderEntry>[...subdirs, ...files];
  }
}
