import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/core/text/source_rename.dart';

void main() {
  group('normaliseRenameInput', () {
    test(
      'should return null for null input (cancelled rename) when the behavior is exercised',
      () {
        expect(normaliseRenameInput(null), isNull);
      },
    );

    test(
      'should return null for empty input (clear-the-override sentinel) when the behavior is exercised',
      () {
        expect(normaliseRenameInput(''), isNull);
      },
    );

    test(
      'should return null for whitespace-only input when the behavior is exercised',
      () {
        expect(normaliseRenameInput('   \t  '), isNull);
      },
    );

    test(
      'should trim surrounding whitespace from a real label when the behavior is exercised',
      () {
        expect(normaliseRenameInput('  My Notes  '), 'My Notes');
      },
    );

    test(
      'should pass labels at exactly the cap through unchanged when the behavior is exercised',
      () {
        final atCap = 'a' * sourceRenameMaxLength;
        expect(normaliseRenameInput(atCap), atCap);
      },
    );

    test(
      'should truncate labels past the cap to the rune-count limit when the behavior is exercised',
      () {
        final overCap = 'a' * (sourceRenameMaxLength + 16);
        final result = normaliseRenameInput(overCap);
        expect(result, isNotNull);
        expect(result!.runes.length, sourceRenameMaxLength);
      },
    );

    test(
      'should confirm that truncation runs on codepoints not UTF-16 code units '
      '(emoji do not get split mid-pair) when the behavior is exercised',
      () {
        // Each '😀' is one rune but two UTF-16 code units. Substring
        // truncation on length would split a surrogate pair.
        final emojiRun = '😀' * (sourceRenameMaxLength + 4);
        final result = normaliseRenameInput(emojiRun);
        expect(result, isNotNull);
        expect(result!.runes.length, sourceRenameMaxLength);
        // No replacement character / mojibake from a split pair.
        expect(result, isNot(contains('�')));
      },
    );

    test(
      'should reject whitespace-only payload that survives truncation when the behavior is exercised',
      () {
        // Truncation of a pathological run of trailing spaces still
        // leaves spaces; the trimRight inside normaliseRenameInput
        // collapses to empty → null.
        final whitespaceRun = ' ' * (sourceRenameMaxLength + 8);
        expect(normaliseRenameInput(whitespaceRun), isNull);
      },
    );
  });
}
