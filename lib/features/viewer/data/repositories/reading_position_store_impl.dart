import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logger/logger.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/reading_position.dart';
import 'package:markdown_viewer/features/viewer/domain/repositories/reading_position_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences`-backed [ReadingPositionStore].
///
/// Each document's position lives under a key of the form
/// `reading.<sha256(path)>`. The sha is intentional — pref keys end
/// up in iOS / Android backup blobs and we do not want raw file
/// paths leaking into those, especially for documents in private
/// directories. The value is a small JSON object with the offset
/// (double) and the save timestamp (ISO-8601 string).
///
/// Reads are synchronous against the already-loaded
/// [SharedPreferences] instance the composition root injects, so
/// the viewer can decide whether to restore a position inside a
/// `WidgetsBinding.addPostFrameCallback` without having to schedule
/// an async hop first (which would be visible as a flash of the
/// document at offset 0 before the jump).
class ReadingPositionStoreImpl implements ReadingPositionStore {
  ReadingPositionStoreImpl(this._prefs, {Logger? logger})
    : _logger = logger ?? Logger();

  final SharedPreferences _prefs;
  final Logger _logger;

  static const String _keyPrefix = 'reading.';

  @override
  ReadingPosition? read(DocumentId documentId) {
    final raw = _prefs.getString(_keyFor(documentId));
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final offset = (decoded['offset'] as num?)?.toDouble();
      final savedAtRaw = decoded['savedAt'] as String?;
      if (offset == null || savedAtRaw == null) {
        return null;
      }
      final savedAt = DateTime.tryParse(savedAtRaw);
      if (savedAt == null) {
        return null;
      }
      return ReadingPosition(
        documentId: documentId,
        offset: offset,
        savedAt: savedAt,
      );
    } on Object catch (e, st) {
      // A corrupt / legacy entry should not poison the reader.
      // Beyond `FormatException` from `jsonDecode`, the explicit
      // `as Map<String, dynamic>` cast can throw `TypeError` if
      // the stored shape has drifted, and a hand-edited entry
      // could theoretically trip any number of other exceptions.
      // Treat every failure as "no bookmark" so the document
      // opens normally; the next explicit save overwrites the
      // bad blob.
      _logger.e(
        'ReadingPositionStore: could not decode entry for $documentId',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  @override
  Future<void> write(ReadingPosition position) {
    final encoded = jsonEncode({
      'offset': position.offset,
      'savedAt': position.savedAt.toUtc().toIso8601String(),
    });
    return _prefs.setString(_keyFor(position.documentId), encoded);
  }

  @override
  Future<void> clear(DocumentId documentId) =>
      _prefs.remove(_keyFor(documentId));

  static String _keyFor(DocumentId documentId) {
    final hash = sha256.convert(utf8.encode(documentId.value)).toString();
    return '$_keyPrefix$hash';
  }
}
