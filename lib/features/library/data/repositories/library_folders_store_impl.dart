import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:markdown_viewer/core/path/sandbox_path.dart';
import 'package:markdown_viewer/features/library/domain/entities/library_folder.dart';
import 'package:markdown_viewer/features/library/domain/repositories/library_folders_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences`-backed [LibraryFoldersStore].
///
/// The list is encoded as a single JSON array under the key
/// [_storageKey]. Each entry is shaped as:
///
/// ```json
/// {
///   "path": "<String>",
///   "addedAt": "<ISO-8601 String>",
///   "bookmark": "<base64 String, optional>"
/// }
/// ```
///
/// The `bookmark` field carries the iOS security-scoped
/// `NSURL.bookmarkData` blob produced by `LibraryFoldersChannel`
/// at pick time. It is optional for backward compatibility with
/// entries written by older builds and because Android / desktop
/// do not need it; the enumerator treats `null` as "use dart:io
/// directly" and a non-null value as "route through the native
/// channel".
///
/// Reads are synchronous against the already-loaded
/// [SharedPreferences] instance the composition root injects. A
/// corrupt blob (manually edited prefs, schema drift, partial
/// write) is treated as "no folders" rather than thrown — the
/// drawer falls back to its empty state, the next add repopulates
/// the list. This mirrors the pattern in `RecentDocumentsStoreImpl`
/// and `ReadingPositionStoreImpl`.
class LibraryFoldersStoreImpl implements LibraryFoldersStore {
  LibraryFoldersStoreImpl(this._prefs, {Logger? logger}) : _logger = logger;

  final SharedPreferences _prefs;

  /// Optional logger used to record corrupt-prefs recoveries. Nullable
  /// so tests can omit it; production wires this from
  /// `appLoggerProvider` at the composition root.
  final Logger? _logger;

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
        final bookmarkRaw = item['bookmark'];
        entries.add(
          LibraryFolder(
            // Portable form resolves back to the current absolute
            // path even after an iOS container-UUID change. Legacy
            // entries written as raw absolute paths still decode
            // because `fromPortable` passes non-sandbox strings
            // through unchanged; the next `write()` rewrites them in
            // portable form, migrating the population over time.
            // Reference: security-review SR-20260419-013.
            path: SandboxPath.fromPortable(path),
            addedAt: addedAt,
            bookmark:
                bookmarkRaw is String && bookmarkRaw.isNotEmpty
                    ? bookmarkRaw
                    : null,
          ),
        );
      }
      return entries;
    } on Object catch (error, stackTrace) {
      // Corrupt prefs fall through as an empty list so the drawer's
      // empty state can recover gracefully, but the decode error is
      // worth seeing in the log — a repeating entry here means a
      // schema bug or a hand-edited prefs file.
      _logger?.w(
        'Corrupt library.folders blob — treating as empty',
        error: error,
        stackTrace: stackTrace,
      );
      return const <LibraryFolder>[];
    }
  }

  @override
  Future<void> write(List<LibraryFolder> folders) {
    final encoded = jsonEncode(
      folders.map((folder) {
        final map = <String, Object>{
          // Persist the portable form so an iOS container-UUID change
          // (dev reinstall, future Apple migration) does not strand
          // entries that sit inside the app sandbox. SAF
          // `content://` URIs and external paths sit outside the
          // sandbox roots; `toPortable` returns them unchanged.
          // Reference: security-review SR-20260419-013.
          'path': SandboxPath.toPortable(folder.path),
          'addedAt': folder.addedAt.toUtc().toIso8601String(),
        };
        final bookmark = folder.bookmark;
        if (bookmark != null && bookmark.isNotEmpty) {
          map['bookmark'] = bookmark;
        }
        return map;
      }).toList(),
    );
    return _prefs.setString(_storageKey, encoded);
  }
}
