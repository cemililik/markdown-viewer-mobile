import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/presentation/screens/viewer_screen.dart';

void main() {
  group('buildShareFilename', () {
    test('should return title as-is when no transformation needed', () {
      expect(buildShareFilename('My Document'), 'My Document');
    });

    test('should strip .md extension when the behavior is exercised', () {
      expect(buildShareFilename('notes.md'), 'notes');
    });

    test('should strip .markdown extension when the behavior is exercised', () {
      expect(buildShareFilename('notes.markdown'), 'notes');
    });

    test(
      'should strip extension case-insensitively when the behavior is exercised',
      () {
        expect(buildShareFilename('notes.MD'), 'notes');
        expect(buildShareFilename('notes.Markdown'), 'notes');
      },
    );

    test(
      'should trim whitespace before extension strip to prevent double extension when the behavior is exercised',
      () {
        // "title.md " → trim → "title.md" → strip → "title"
        // Without the leading trim, the regex would not match and the
        // caller's appended ".md" would produce "title.md .md".
        expect(buildShareFilename('title.md '), 'title');
      },
    );

    test(
      'should replace each filesystem-unsafe character with dash when the behavior is exercised',
      () {
        expect(buildShareFilename('a:b'), 'a-b');
        expect(buildShareFilename('a/b'), 'a-b');
        expect(buildShareFilename('a<b'), 'a-b');
        expect(buildShareFilename('a>b'), 'a-b');
        expect(buildShareFilename('a"b'), 'a-b');
        expect(buildShareFilename('a|b'), 'a-b');
        expect(buildShareFilename('a?b'), 'a-b');
        expect(buildShareFilename('a*b'), 'a-b');
      },
    );

    test('should fall back to "document" when title is empty', () {
      expect(buildShareFilename(''), 'document');
    });

    test(
      'should fall back to "document" when title contains only unsafe chars',
      () {
        expect(buildShareFilename('///***'), 'document');
      },
    );

    test(
      'should collapse consecutive dashes from multiple unsafe chars when the behavior is exercised',
      () {
        expect(buildShareFilename('a///b'), 'a-b');
      },
    );

    test(
      'should collapse multiple separate runs of unsafe chars independently when the behavior is exercised',
      () {
        expect(buildShareFilename('a///b***c'), 'a-b-c');
      },
    );

    test(
      'should strip leading and trailing dashes when the behavior is exercised',
      () {
        expect(buildShareFilename(':title:'), 'title');
      },
    );

    test('should fall back to "document" when title is only whitespace', () {
      expect(buildShareFilename('   '), 'document');
    });

    test(
      'should truncate to 64 characters by default when the behavior is exercised',
      () {
        final long = 'a' * 100;
        expect(buildShareFilename(long).length, 64);
      },
    );

    test('should respect custom maxLength when the behavior is exercised', () {
      expect(buildShareFilename('a' * 100, maxLength: 20).length, 20);
    });

    test(
      'should trim trailing whitespace introduced by truncation when the behavior is exercised',
      () {
        // 63 'a' chars + space + 'b' — truncating at 64 leaves trailing space.
        final title = '${'a' * 63} b';
        final result = buildShareFilename(title, maxLength: 64);
        expect(result, isNot(endsWith(' ')));
      },
    );

    test('should not fall back when title has only trailing extension', () {
      // ".md" after trim + strip → "" → fallback
      expect(buildShareFilename('.md'), 'document');
    });
  });
}
