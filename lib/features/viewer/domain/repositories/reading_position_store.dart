import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/reading_position.dart';

/// Port for persisting and retrieving the user's last reading
/// position inside a single markdown document.
///
/// Intentionally minimal — read / write / clear, all keyed by
/// [DocumentId]. The implementation is free to use
/// `SharedPreferences`, a real database, or an in-memory fake; the
/// only constraint is that [read] must be **synchronous** so the
/// viewer can decide whether to restore a position before the
/// first frame paints, without inducing a flash of the wrong
/// scroll offset.
abstract interface class ReadingPositionStore {
  /// Returns the persisted position for [documentId], or `null` if
  /// the user has never bookmarked this document. Synchronous so
  /// the viewer can apply it inside a `PostFrameCallback` without
  /// awaiting disk I/O.
  ReadingPosition? read(DocumentId documentId);

  /// Persists [position] for [position.documentId]. Returns the
  /// underlying write [Future] so callers can `ignore()` it for
  /// fire-and-forget UX or `await` it in tests.
  Future<void> write(ReadingPosition position);

  /// Removes any persisted position for [documentId]. Idempotent —
  /// no error if there was no position to clear.
  Future<void> clear(DocumentId documentId);
}
