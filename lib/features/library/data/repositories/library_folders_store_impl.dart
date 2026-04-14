import 'dart:convert';

import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/repositories/library_folders_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences`-backed [LibraryFoldersStore].
///
/// The list is encoded as a single JSON array under the key
/// [_storageKey], with each entry shaped as
/// `{"path": <String>, "addedAt": <ISO-8601 String>}`. The schema
/// is deliberately tiny — there is no per-entry label or pinned
/// flag yet because the drawer renders folders straight from
/// their basename and the order on disk is the order shown.
///
/// Reads are synchronous against the already-loaded
/// [SharedPreferences] instance the composition root injects. A
/// corrupt blob (manually edited prefs, schema drift, partial
/// write) is treated as "no folders" rather than thrown — the
/// drawer falls back to its empty state, the next add repopulates
/// the list. This mirrors the pattern in `RecentDocumentsStoreImpl`
/// and `ReadingPositionStoreImpl`.
class LibraryFoldersStoreImpl implements LibraryFoldersStore {
  LibraryFoldersStoreImpl(this._prefs);

  final SharedPreferences _prefs;

  static const String _storageKey = 'library.folders';

  @override
  List<LibraryFolder> read() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const <LibraryFolder>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <LibraryFolder>[];
      }
      final entries = <LibraryFolder>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final path = item['path'];
        final addedAtRaw = item['addedAt'];
        if (path is! String || path.isEmpty) continue;
        if (addedAtRaw is! String) continue;
        final addedAt = DateTime.tryParse(addedAtRaw);
        if (addedAt == null) continue;
        entries.add(LibraryFolder(path: path, addedAt: addedAt));
      }
      return entries;
    } on Object {
      return const <LibraryFolder>[];
    }
  }

  @override
  Future<void> write(List<LibraryFolder> folders) {
    final encoded = jsonEncode(
      folders
          .map(
            (folder) => <String, String>{
              'path': folder.path,
              'addedAt': folder.addedAt.toUtc().toIso8601String(),
            },
          )
          .toList(),
    );
    return _prefs.setString(_storageKey, encoded);
  }
}
