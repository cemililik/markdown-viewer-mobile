import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/presentation/screens/viewer_screen.dart';

void main() {
  group('buildShareFilename', () {
    test('returns title as-is when no transformation needed', () {
      expect(buildShareFilename('My Document'), 'My Document');
    });

    test('strips .md extension', () {
      expect(buildShareFilename('notes.md'), 'notes');
    });

    test('strips .markdown extension', () {
      expect(buildShareFilename('notes.markdown'), 'notes');
    });

    test('strips extension case-insensitively', () {
      expect(buildShareFilename('notes.MD'), 'notes');
      expect(buildShareFilename('notes.Markdown'), 'notes');
    });

    test(
      'trims whitespace before extension strip to prevent double extension',
      () {
        // "title.md " → trim → "title.md" → strip → "title"
        // Without the leading trim, the regex would not match and the
        // caller's appended ".md" would produce "title.md .md".
        expect(buildShareFilename('title.md '), 'title');
      },
    );

    test('replaces each filesystem-unsafe character with dash', () {
      expect(buildShareFilename('a:b'), 'a-b');
      expect(buildShareFilename('a/b'), 'a-b');
      expect(buildShareFilename('a<b'), 'a-b');
      expect(buildShareFilename('a>b'), 'a-b');
      expect(buildShareFilename('a"b'), 'a-b');
      expect(buildShareFilename('a|b'), 'a-b');
      expect(buildShareFilename('a?b'), 'a-b');
      expect(buildShareFilename('a*b'), 'a-b');
    });

    test('falls back to "document" when title is empty', () {
      expect(buildShareFilename(''), 'document');
    });

    test('falls back to "document" when title contains only unsafe chars', () {
      expect(buildShareFilename('///***'), 'document');
    });

    test('collapses consecutive dashes from multiple unsafe chars', () {
      expect(buildShareFilename('a///b'), 'a-b');
    });

    test('strips leading and trailing dashes', () {
      expect(buildShareFilename(':title:'), 'title');
    });

    test('falls back to "document" when title is only whitespace', () {
      expect(buildShareFilename('   '), 'document');
    });

    test('truncates to 64 characters by default', () {
      final long = 'a' * 100;
      expect(buildShareFilename(long).length, 64);
    });

    test('respects custom maxLength', () {
      expect(buildShareFilename('a' * 100, maxLength: 20).length, 20);
    });

    test('trims trailing whitespace introduced by truncation', () {
      // 63 'a' chars + space + 'b' — truncating at 64 leaves trailing space.
      final title = '${'a' * 63} b';
      final result = buildShareFilename(title, maxLength: 64);
      expect(result, isNot(endsWith(' ')));
    });

    test('does not fall back when title has only trailing extension', () {
      // ".md" after trim + strip → "" → fallback
      expect(buildShareFilename('.md'), 'document');
    });
  });
}
