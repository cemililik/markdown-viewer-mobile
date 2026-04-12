import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';

/// Port for loading and parsing a markdown document.
///
/// Lives in the domain layer so the application layer depends only on
/// abstractions — see `docs/standards/architecture-standards.md` for
/// the layer rules. Concrete implementations live in
/// `lib/features/viewer/data/repositories/`.
abstract interface class DocumentRepository {
  /// Reads the file at [path] and returns a parsed [Document].
  ///
  /// Throws a concrete [Failure] subtype from `lib/core/errors/` when
  /// the file cannot be read or parsed. Never throws raw I/O or
  /// formatting exceptions — implementations are responsible for
  /// translating those into [Failure]s at the repository boundary.
  Future<Document> load(DocumentId path);
}
