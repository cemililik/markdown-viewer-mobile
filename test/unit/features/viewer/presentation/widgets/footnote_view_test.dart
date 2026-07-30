import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/footnote_view.dart';

void main() {
  group('extractFootnotes', () {
    test(
      'should return empty map for source with no definitions when the behavior is exercised',
      () {
        expect(extractFootnotes('Hello world.'), isEmpty);
      },
    );

    test(
      'should extract a single-line definition when the behavior is exercised',
      () {
        const source = 'Text[^1] here.\n\n[^1]: The footnote content.';
        final result = extractFootnotes(source);

        expect(result, hasLength(1));
        expect(result['1'], 'The footnote content.');
      },
    );

    test(
      'should extract multiple definitions when the behavior is exercised',
      () {
        const source = '''
See [^a] and [^b].

[^a]: First footnote.
[^b]: Second footnote.
''';
        final result = extractFootnotes(source);

        expect(result['a'], 'First footnote.');
        expect(result['b'], 'Second footnote.');
      },
    );

    test(
      'should join multi-line continuation into a single string when the behavior is exercised',
      () {
        const source = '[^1]: First line.\n    Continuation here.';
        final result = extractFootnotes(source);

        expect(result['1'], 'First line. Continuation here.');
      },
    );

    test(
      'should trim leading and trailing whitespace from content when the behavior is exercised',
      () {
        const source = '[^x]:   spaced content   ';
        expect(extractFootnotes(source)['x'], 'spaced content');
      },
    );

    test(
      'should handle alphanumeric and hyphenated ids when the behavior is exercised',
      () {
        const source = '[^fn-abc]: Alpha.\n[^123]: Numeric.';
        final result = extractFootnotes(source);

        expect(result['fn-abc'], 'Alpha.');
        expect(result['123'], 'Numeric.');
      },
    );

    test(
      'should return empty content string for a definition with no body when the behavior is exercised',
      () {
        const source = '[^empty]:';
        expect(extractFootnotes(source)['empty'], '');
      },
    );
  });

  group('stripFootnoteDefs', () {
    test('should return source unchanged when no definitions are present', () {
      const source = 'Hello world.';
      expect(stripFootnoteDefs(source), source);
    });

    test(
      'should remove a single-line definition when the behavior is exercised',
      () {
        const source = 'Body text.\n\n[^1]: Footnote here.\n\nMore text.';
        final result = stripFootnoteDefs(source);

        expect(result, isNot(contains('[^1]:')));
        expect(result, contains('Body text.'));
        expect(result, contains('More text.'));
      },
    );

    test(
      'should remove a multi-line definition when the behavior is exercised',
      () {
        const source = '[^1]: Line one.\n    Line two.\n\nParagraph.';
        final result = stripFootnoteDefs(source);

        expect(result, isNot(contains('[^1]:')));
        expect(result, isNot(contains('Line one.')));
        expect(result, isNot(contains('Line two.')));
        expect(result, contains('Paragraph.'));
      },
    );

    test(
      'should remove multiple definitions when the behavior is exercised',
      () {
        const source = '[^a]: Alpha.\n[^b]: Beta.\n\nContent.';
        final result = stripFootnoteDefs(source);

        expect(result, isNot(contains('[^a]:')));
        expect(result, isNot(contains('[^b]:')));
        expect(result, contains('Content.'));
      },
    );

    test(
      'should not remove inline references — only block definitions when the behavior is exercised',
      () {
        const source = 'See[^1] this.\n\n[^1]: Definition.';
        final result = stripFootnoteDefs(source);

        expect(result, contains('[^1]'));
        expect(result, isNot(contains('[^1]:')));
      },
    );
  });
}
