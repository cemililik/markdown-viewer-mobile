import 'dart:io';

import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/features/viewer/data/parsers/markdown_parser.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/domain/repositories/document_repository.dart';

/// File-backed [DocumentRepository] implementation.
///
/// Reads the file at the given [DocumentId] path from the local file
/// system and hands the bytes to a [MarkdownParser]. All low-level
/// exceptions are translated into a concrete [Failure] subtype at this
/// boundary so the rest of the application only ever sees typed
/// failures — see `docs/standards/error-handling-standards.md`.
final class DocumentRepositoryImpl implements DocumentRepository {
  const DocumentRepositoryImpl({required MarkdownParser parser})
    : _parser = parser;

  final MarkdownParser _parser;

  @override
  Future<Document> load(DocumentId path) async {
    final file = File(path.value);
    final List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } on PathNotFoundException catch (e) {
      throw FileNotFoundFailure(
        message: 'Markdown file not found: ${path.value}',
        cause: e,
      );
    } on FileSystemException catch (e) {
      // PathNotFoundException is a subtype and is handled above, so a
      // bare FileSystemException here is most commonly an access /
      // permission problem. Map it accordingly.
      throw PermissionDeniedFailure(
        message: 'Cannot read ${path.value}',
        cause: e,
      );
    }

    try {
      return _parser.parse(id: path, bytes: bytes);
    } on FormatException catch (e) {
      throw ParseFailure(
        message: 'Markdown file is not valid UTF-8 or cannot be parsed',
        cause: e,
      );
    }
  }
}
