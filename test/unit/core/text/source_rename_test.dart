import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/core/text/source_rename.dart';

void main() {
  group('normaliseRenameInput', () {
    test('returns null for null input (cancelled rename)', () {
      expect(normaliseRenameInput(null), isNull);
    });

    test('returns null for empty input (clear-the-override sentinel)', () {
      expect(normaliseRenameInput(''), isNull);
    });

    test('returns null for whitespace-only input', () {
      expect(normaliseRenameInput('   \t  '), isNull);
    });

    test('trims surrounding whitespace from a real label', () {
      expect(normaliseRenameInput('  My Notes  '), 'My Notes');
    });

    test('passes labels at exactly the cap through unchanged', () {
      final atCap = 'a' * sourceRenameMaxLength;
      expect(normaliseRenameInput(atCap), atCap);
    });

    test('truncates labels past the cap to the rune-count limit', () {
      final overCap = 'a' * (sourceRenameMaxLength + 16);
      final result = normaliseRenameInput(overCap);
      expect(result, isNotNull);
      expect(result!.runes.length, sourceRenameMaxLength);
    });

    test('truncation runs on codepoints not UTF-16 code units '
        '(emoji do not get split mid-pair)', () {
      // Each '😀' is one rune but two UTF-16 code units. Substring
      // truncation on length would split a surrogate pair.
      final emojiRun = '😀' * (sourceRenameMaxLength + 4);
      final result = normaliseRenameInput(emojiRun);
      expect(result, isNotNull);
      expect(result!.runes.length, sourceRenameMaxLength);
      // No replacement character / mojibake from a split pair.
      expect(result, isNot(contains('�')));
    });

    test('rejects whitespace-only payload that survives truncation', () {
      // Truncation of a pathological run of trailing spaces still
      // leaves spaces; the trimRight inside normaliseRenameInput
      // collapses to empty → null.
      final whitespaceRun = ' ' * (sourceRenameMaxLength + 8);
      expect(normaliseRenameInput(whitespaceRun), isNull);
    });
  });
}
