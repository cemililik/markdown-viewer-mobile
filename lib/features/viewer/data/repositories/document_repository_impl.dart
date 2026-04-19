import 'dart:io';
import 'dart:isolate';

import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/features/viewer/data/parsers/markdown_parser.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/domain/repositories/document_repository.dart';
import 'package:path/path.dart' as p;

/// File-backed [DocumentRepository] implementation.
///
/// Reads the file at the given [DocumentId] path from the local file
/// system and hands the bytes to a [MarkdownParser]. All low-level
/// exceptions are translated into a concrete [Failure] subtype at this
/// boundary so the rest of the application only ever sees typed
/// failures — see `docs/standards/error-handling-standards.md`.
///
/// Parsing a large file decodes the entire source as UTF-8 and walks
/// the markdown AST, which can easily exceed a 16 ms frame budget on
/// mid-range devices. For inputs at or above
/// [_isolateThresholdBytes], the parse is offloaded to a background
/// isolate via [Isolate.run] so the UI isolate stays responsive. The
/// threshold matches the one documented in `docs/rendering-pipeline.md`.
final class DocumentRepositoryImpl implements DocumentRepository {
  const DocumentRepositoryImpl({required MarkdownParser parser})
    : _parser = parser;

  final MarkdownParser _parser;

  static const int _isolateThresholdBytes = 200 * 1024;

  @override
  Future<Document> load(DocumentId path) async {
    // Defense-in-depth path scrub. Native channels validate incoming
    // paths at the platform boundary; this guard stops a malformed
    // or deliberately crafted Dart-side value from reaching
    // `File(...)` — specifically rejects null bytes (POSIX truncates
    // reads at `\x00`, so `.../safe.md\x00/etc/passwd` would
    // otherwise resolve against the filesystem) and normalises `..`
    // sequences before the read opens.
    // Reference: security-review SR-20260419-011.
    final raw = path.value;
    if (raw.contains('\x00')) {
      throw const ParseFailure(message: 'Document path contains a NUL byte');
    }
    final normalized = p.normalize(raw);
    final file = File(normalized);
    final List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } on PathNotFoundException catch (e) {
      throw FileNotFoundFailure(
        message: 'Markdown file not found: ${path.value}',
        cause: e,
      );
    } on FileSystemException catch (e) {
      // Some platforms (older Dart SDKs, certain file systems) still
      // raise a plain [FileSystemException] instead of the more
      // specific [PathNotFoundException] for ENOENT. Detect that case
      // by osError code / message and surface it as a
      // [FileNotFoundFailure] so the UI can show a "file may have
      // been moved or deleted" message instead of a misleading
      // "permission denied".
      if (_isMissingFile(e)) {
        throw FileNotFoundFailure(
          message: 'Markdown file not found: ${path.value}',
          cause: e,
        );
      }
      throw PermissionDeniedFailure(
        message: 'Cannot read ${path.value}',
        cause: e,
      );
    }

    try {
      if (bytes.length >= _isolateThresholdBytes) {
        // Capture `_parser` in a local so the closure sent to the
        // isolate does not need to serialise `this`.
        final parser = _parser;
        return await Isolate.run(
          () => parser.parse(id: path, bytes: bytes),
          debugName: 'MarkdownParser',
        );
      }
      return _parser.parse(id: path, bytes: bytes);
    } on FormatException catch (e) {
      throw ParseFailure(
        message: 'Markdown file is not valid UTF-8 or cannot be parsed',
        cause: e,
      );
    } on Failure {
      // A nested data-layer call already threw a typed failure — let
      // it propagate unchanged instead of masking it with
      // [UnknownFailure] below.
      rethrow;
    } on Exception catch (e) {
      // Defensive catch: any other exception escaping the parser
      // (upstream `markdown` package bug, custom syntax bug, etc.)
      // must not reach application code as a raw exception. Wrap it
      // in a typed [UnknownFailure] so every caller only needs to
      // handle the [Failure] hierarchy.
      throw UnknownFailure(
        message: 'Unexpected error while parsing ${path.value}',
        cause: e,
      );
    }
  }

  bool _isMissingFile(FileSystemException e) {
    final osError = e.osError;
    if (osError == null) {
      return false;
    }
    // ENOENT on POSIX and ERROR_FILE_NOT_FOUND / ERROR_PATH_NOT_FOUND
    // on Windows.
    if (osError.errorCode == 2 || osError.errorCode == 3) {
      return true;
    }
    final message = osError.message.toLowerCase();
    return message.contains('no such file or directory') ||
        message.contains('cannot find');
  }
}
