import 'package:markdown_viewer/features/viewer/data/parsers/markdown_parser.dart';
import 'package:markdown_viewer/features/viewer/data/repositories/document_repository_impl.dart';
import 'package:markdown_viewer/features/viewer/domain/repositories/document_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'document_repository_provider.g.dart';

/// Exposes the singleton [DocumentRepository] to the rest of the app.
///
/// The concrete impl and the parser are wired here so every other layer
/// only sees the [DocumentRepository] port — the data layer is the only
/// place that knows about `dart:io` or the underlying `markdown` package.
@Riverpod(keepAlive: true)
DocumentRepository documentRepository(Ref ref) {
  return const DocumentRepositoryImpl(parser: MarkdownParser());
}
