import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/data/parsers/markdown_parser.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';

void main() {
  const id = DocumentId('fixture');
  const parser = MarkdownParser();

  List<int> bytes(String s) => utf8.encode(s);

  String fixture(String name) {
    return File('test/fixtures/markdown/$name').readAsStringSync();
  }

  group('MarkdownParser', () {
    test('should return an empty document for empty input', () {
      final doc = parser.parse(id: id, bytes: const []);

      expect(doc.source, '');
      expect(doc.headings, isEmpty);
      expect(doc.lineCount, 0);
      expect(doc.byteSize, 0);
      expect(doc.id, id);
    });

    test('should strip a UTF-8 BOM from the decoded source', () {
      final withBom = <int>[0xEF, 0xBB, 0xBF, ...bytes('# hello')];

      final doc = parser.parse(id: id, bytes: withBom);

      expect(doc.source, '# hello');
      expect(doc.headings.single.text, 'hello');
    });

    test('should extract a single heading from a minimal document', () {
      final source = fixture('minimal.md');

      final doc = parser.parse(id: id, bytes: bytes(source));

      expect(doc.source, source);
      expect(doc.headings, hasLength(1));
      expect(doc.headings.single.text, 'Hello');
      expect(doc.headings.single.level, 1);
      expect(doc.headings.single.anchor, 'hello');
      expect(doc.lineCount, greaterThan(0));
      expect(doc.byteSize, bytes(source).length);
    });

    test('should extract headings in document order with stable anchors', () {
      final source = fixture('headings.md');

      final doc = parser.parse(id: id, bytes: bytes(source));

      expect(doc.headings.map((h) => h.level).toList(), [1, 2, 3, 2, 2, 6]);
      expect(doc.headings.map((h) => h.text).toList(), [
        'Top Level',
        'Section One',
        'Subsection 1.1',
        'Section Two',
        'Section One',
        'Deepest',
      ]);
      expect(doc.headings.map((h) => h.anchor).toList(), [
        'top-level',
        'section-one',
        'subsection-11',
        'section-two',
        'section-one-1',
        'deepest',
      ]);
    });

    test('should walk containers recursively to find nested headings', () {
      // Regression guard: the previous implementation only inspected
      // top-level nodes from `document.parseLines` and would silently
      // drop headings that appear inside blockquotes or list items.
      final source = fixture('nested.md');

      final doc = parser.parse(id: id, bytes: bytes(source));

      final texts = doc.headings.map((h) => h.text).toList();
      expect(texts, contains('Top'));
      expect(texts, contains('After the containers'));
      expect(
        texts,
        contains('Quoted Section'),
        reason: 'heading nested in a blockquote must be collected',
      );
      expect(
        texts,
        contains('Nested in a list'),
        reason: 'heading nested in a list item must be collected',
      );
    });

    test('should ignore non-heading top-level blocks', () {
      final source = fixture('typical.md');

      final doc = parser.parse(id: id, bytes: bytes(source));

      expect(doc.headings, hasLength(5));
      expect(doc.headings.first.text, 'Project Name');
      expect(doc.headings.first.level, 1);
    });

    test('should throw FormatException on invalid UTF-8', () {
      // 0xC3 starts a two-byte sequence but the follow-up byte is
      // missing, which is not valid UTF-8.
      final bad = [0xC3];

      expect(
        () => parser.parse(id: id, bytes: bad),
        throwsA(isA<FormatException>()),
      );
    });

    test('should count lines for a terminal newline correctly', () {
      const source = 'a\nb\nc\n';

      final doc = parser.parse(id: id, bytes: bytes(source));

      expect(doc.lineCount, 3);
    });

    test(
      'should count the last line when the file has no trailing newline',
      () {
        const source = 'a\nb\nc';

        final doc = parser.parse(id: id, bytes: bytes(source));

        expect(doc.lineCount, 3);
      },
    );
  });
}
