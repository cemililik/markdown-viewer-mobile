import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';

/// Persisted reading position for a single markdown document.
///
/// Kept as a tiny plain class (no freezed) because its surface area
/// is two fields and it never round-trips through code generation —
/// the data layer encodes / decodes it with hand-written JSON to
/// avoid a build_runner dependency for one tiny value type.
final class ReadingPosition {
  const ReadingPosition({
    required this.documentId,
    required this.offset,
    required this.savedAt,
  });

  final DocumentId documentId;
  final double offset;
  final DateTime savedAt;
}
