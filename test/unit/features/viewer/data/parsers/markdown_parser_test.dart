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
      // act
      final doc = parser.parse(id: id, bytes: const []);

      // assert
      expect(doc.source, '');
      expect(doc.headings, isEmpty);
      expect(doc.lineCount, 0);
      expect(doc.byteSize, 0);
      expect(doc.id, id);
    });

    test('should strip a UTF-8 BOM from the decoded source', () {
      // arrange
      final withBom = <int>[0xEF, 0xBB, 0xBF, ...bytes('# hello')];

      // act
      final doc = parser.parse(id: id, bytes: withBom);

      // assert
      expect(doc.source, '# hello');
      expect(doc.headings.single.text, 'hello');
    });

    test('should extract a single heading from a minimal document', () {
      // arrange
      final source = fixture('minimal.md');

      // act
      final doc = parser.parse(id: id, bytes: bytes(source));

      // assert
      expect(doc.source, source);
      expect(doc.headings, hasLength(1));
      expect(doc.headings.single.text, 'Hello');
      expect(doc.headings.single.level, 1);
      expect(doc.headings.single.anchor, 'hello');
      expect(doc.lineCount, greaterThan(0));
      expect(doc.byteSize, bytes(source).length);
    });

    test('should extract headings in document order with stable anchors', () {
      // arrange
      final source = fixture('headings.md');

      // act
      final doc = parser.parse(id: id, bytes: bytes(source));

      // assert — level and order
      expect(doc.headings.map((h) => h.level).toList(), [1, 2, 3, 2, 2, 6]);
      // assert — plain-text content
      expect(doc.headings.map((h) => h.text).toList(), [
        'Top Level',
        'Section One',
        'Subsection 1.1',
        'Section Two',
        'Section One',
        'Deepest',
      ]);
      // assert — anchors are slugified and duplicates disambiguated
      expect(doc.headings.map((h) => h.anchor).toList(), [
        'top-level',
        'section-one',
        'subsection-11',
        'section-two',
        'section-one-1',
        'deepest',
      ]);
    });

    test('should ignore non-heading top-level blocks', () {
      // arrange
      final source = fixture('typical.md');

      // act
      final doc = parser.parse(id: id, bytes: bytes(source));

      // assert — typical.md has five unique headings (h1 + 4×h2)
      expect(doc.headings, hasLength(5));
      expect(doc.headings.first.text, 'Project Name');
      expect(doc.headings.first.level, 1);
    });

    test('should throw FormatException on invalid UTF-8', () {
      // arrange — 0xC3 starts a two-byte sequence but the follow-up
      // byte is missing, which is not valid UTF-8.
      final bad = [0xC3];

      // act & assert
      expect(
        () => parser.parse(id: id, bytes: bad),
        throwsA(isA<FormatException>()),
      );
    });

    test('should count lines for a terminal newline correctly', () {
      // arrange
      const source = 'a\nb\nc\n';

      // act
      final doc = parser.parse(id: id, bytes: bytes(source));

      // assert — three newlines, three logical lines.
      expect(doc.lineCount, 3);
    });

    test(
      'should count the last line when the file has no trailing newline',
      () {
        // arrange
        const source = 'a\nb\nc';

        // act
        final doc = parser.parse(id: id, bytes: bytes(source));

        // assert
        expect(doc.lineCount, 3);
      },
    );
  });
}
