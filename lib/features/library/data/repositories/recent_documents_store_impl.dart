import 'dart:convert';

import 'package:markdown_viewer/core/path/sandbox_path.dart';
import 'package:markdown_viewer/features/library/domain/entities/recent_document.dart';
import 'package:markdown_viewer/features/library/domain/repositories/recent_documents_store.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences`-backed [RecentDocumentsStore].
///
/// The list is encoded as a single JSON array under the key
/// [_storageKey]. Each entry is shaped as:
///
/// ```json
/// {
///   "path": "<String>",
///   "openedAt": "<ISO-8601 String>",
///   "pinned": <bool, default false>,
///   "preview": "<String, optional>"
/// }
/// ```
///
/// Stored most-recent-first so the controller can hand the list
/// straight to the UI without a re-sort on every read. Legacy
/// entries that were written before the `pinned` and `preview`
/// fields existed are still accepted — the reader treats missing
/// fields as `false` / `null` so upgrading from an older build
/// does not wipe the user's recents.
///
/// Reads are synchronous against the already-loaded
/// [SharedPreferences] instance the composition root injects. A
/// corrupt blob (manually edited prefs, schema drift, partially
/// written value) is treated as "no recents" rather than thrown
/// — the home screen falls back to the empty state, the next
/// successful open repopulates the list.
class RecentDocumentsStoreImpl implements RecentDocumentsStore {
  RecentDocumentsStoreImpl(this._prefs);

  final SharedPreferences _prefs;

  static const String _storageKey = 'library.recentDocuments';

  @override
  List<RecentDocument> read() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const <RecentDocument>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <RecentDocument>[];
      }
      final entries = <RecentDocument>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final path = item['path'];
        final openedAtRaw = item['openedAt'];
        if (path is! String || path.isEmpty) continue;
        if (openedAtRaw is! String) continue;
        final openedAt = DateTime.tryParse(openedAtRaw);
        if (openedAt == null) continue;
        final pinnedRaw = item['pinned'];
        final previewRaw = item['preview'];
        final displayNameRaw = item['displayName'];
        // Resolve any `sandbox:<kind>:<relative>` token written by an
        // earlier session against the CURRENT container's absolute
        // prefix so File(...) can open the file. Absolute paths left
        // over from the pre-sandbox-path version passthrough unchanged
        // — they will either still resolve (unchanged container) or
        // be self-cleaned by the repository on first open failure.
        final absolutePath = SandboxPath.fromPortable(path);
        // Previous versions called `File(absolutePath).existsSync()`
        // here to self-clean stale entries (iOS dev-rebuild container
        // UUID drift). That forced a blocking `stat` per entry on the
        // UI isolate during cold start — 20 entries on SMB / iCloud
        // Drive = 20 serial blocking hops before the first frame.
        //
        // The check has moved out: the viewer surfaces a localised
        // "file no longer available" error when a tap resolves to a
        // missing path, which is the only code path where staleness
        // matters for the user. Keeping the cold-start read purely
        // in-memory is the right-sized fix.
        // Reference: code-review CR-20260419-019.
        entries.add(
          RecentDocument(
            documentId: DocumentId(absolutePath),
            openedAt: openedAt,
            isPinned: pinnedRaw is bool ? pinnedRaw : false,
            preview:
                previewRaw is String && previewRaw.isNotEmpty
                    ? previewRaw
                    : null,
            displayName:
                displayNameRaw is String && displayNameRaw.isNotEmpty
                    ? displayNameRaw
                    : null,
          ),
        );
      }
      return entries;
    } on Object {
      // Corrupt entry should not poison the home screen — see the
      // matching pattern in ReadingPositionStoreImpl.read.
      return const <RecentDocument>[];
    }
  }

  @override
  Future<void> write(List<RecentDocument> documents) {
    final encoded = jsonEncode(
      documents.map((doc) {
        // Store paths in their container-relative `sandbox:cache:foo.md`
        // form when they sit inside the app's own sandbox so a
        // container-UUID change on reinstall / dev rebuild does not
        // invalidate every recents tile. External paths (iCloud Drive,
        // SAF content URIs) passthrough unchanged — those are stable
        // outside our sandbox lifecycle.
        final map = <String, Object>{
          'path': SandboxPath.toPortable(doc.documentId.value),
          'openedAt': doc.openedAt.toUtc().toIso8601String(),
          'pinned': doc.isPinned,
        };
        final preview = doc.preview;
        if (preview != null && preview.isNotEmpty) {
          map['preview'] = preview;
        }
        final displayName = doc.displayName;
        if (displayName != null && displayName.isNotEmpty) {
          map['displayName'] = displayName;
        }
        return map;
      }).toList(),
    );
    return _prefs.setString(_storageKey, encoded);
  }
}
