import 'dart:io';

import 'package:markdown_viewer/features/viewer/data/parsers/markdown_parser.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';

/// Single shared instance of [MarkdownParser] used by every fixture
/// loader in the test tree. The parser is stateless and `const`, so
/// reusing one instance avoids per-call allocation in tests that
/// load many fixtures.
const MarkdownParser _parser = MarkdownParser();

/// Loads a markdown fixture from `test/fixtures/markdown/<name>` and
/// parses it into a [Document].
///
/// Reads the file as **raw bytes** with [File.readAsBytesSync] and
/// passes them straight to [MarkdownParser.parse]. Earlier widget
/// tests called `File.readAsStringSync().codeUnits` to get bytes,
/// which returned UTF-16 code units and corrupted any multibyte
/// glyph (a horizontal-ellipsis `…` in the math fixture was the
/// canary that surfaced this bug). Centralising the loader here
/// keeps every test on the correct UTF-8 path and prevents the
/// `codeUnits` pitfall from reappearing.
Document parseMarkdownFixture(String name) {
  final bytes = File('test/fixtures/markdown/$name').readAsBytesSync();
  return _parser.parse(
    id: DocumentId('test/fixtures/markdown/$name'),
    bytes: bytes,
  );
}
