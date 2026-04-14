import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/footnote_view.dart';

void main() {
  group('extractFootnotes', () {
    test('returns empty map for source with no definitions', () {
      expect(extractFootnotes('Hello world.'), isEmpty);
    });

    test('extracts a single-line definition', () {
      const source = 'Text[^1] here.\n\n[^1]: The footnote content.';
      final result = extractFootnotes(source);

      expect(result, hasLength(1));
      expect(result['1'], 'The footnote content.');
    });

    test('extracts multiple definitions', () {
      const source = '''
See [^a] and [^b].

[^a]: First footnote.
[^b]: Second footnote.
''';
      final result = extractFootnotes(source);

      expect(result['a'], 'First footnote.');
      expect(result['b'], 'Second footnote.');
    });

    test('joins multi-line continuation into a single string', () {
      const source = '[^1]: First line.\n    Continuation here.';
      final result = extractFootnotes(source);

      expect(result['1'], 'First line. Continuation here.');
    });

    test('trims leading and trailing whitespace from content', () {
      const source = '[^x]:   spaced content   ';
      expect(extractFootnotes(source)['x'], 'spaced content');
    });

    test('handles alphanumeric and hyphenated ids', () {
      const source = '[^fn-abc]: Alpha.\n[^123]: Numeric.';
      final result = extractFootnotes(source);

      expect(result['fn-abc'], 'Alpha.');
      expect(result['123'], 'Numeric.');
    });

    test('returns empty content string for a definition with no body', () {
      const source = '[^empty]:';
      expect(extractFootnotes(source)['empty'], '');
    });
  });

  group('stripFootnoteDefs', () {
    test('returns source unchanged when no definitions are present', () {
      const source = 'Hello world.';
      expect(stripFootnoteDefs(source), source);
    });

    test('removes a single-line definition', () {
      const source = 'Body text.\n\n[^1]: Footnote here.\n\nMore text.';
      final result = stripFootnoteDefs(source);

      expect(result, isNot(contains('[^1]:')));
      expect(result, contains('Body text.'));
      expect(result, contains('More text.'));
    });

    test('removes a multi-line definition', () {
      const source = '[^1]: Line one.\n    Line two.\n\nParagraph.';
      final result = stripFootnoteDefs(source);

      expect(result, isNot(contains('[^1]:')));
      expect(result, isNot(contains('Line one.')));
      expect(result, isNot(contains('Line two.')));
      expect(result, contains('Paragraph.'));
    });

    test('removes multiple definitions', () {
      const source = '[^a]: Alpha.\n[^b]: Beta.\n\nContent.';
      final result = stripFootnoteDefs(source);

      expect(result, isNot(contains('[^a]:')));
      expect(result, isNot(contains('[^b]:')));
      expect(result, contains('Content.'));
    });

    test('does not remove inline references — only block definitions', () {
      const source = 'See[^1] this.\n\n[^1]: Definition.';
      final result = stripFootnoteDefs(source);

      // The inline [^1] reference must survive.
      expect(result, contains('[^1]'));
      // The block definition must be gone.
      expect(result, isNot(contains('[^1]:')));
    });
  });
}
