import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/search_highlight_syntax.dart';

// PUA sentinels mirrored from the implementation file for assertion clarity.
const _normalOpen = '\uE000';
const _normalClose = '\uE001';
const _currentOpen = '\uE002';
const _currentClose = '\uE003';

void main() {
  group('buildHighlightedSource', () {
    test('returns original source unchanged when matchOffsets is empty', () {
      const source = 'hello world';

      final result = buildHighlightedSource(
        source: source,
        matchOffsets: const [],
        queryLength: 5,
        currentMatchIndex: 0,
      );

      expect(result, source);
    });

    test('returns original source unchanged when queryLength is zero', () {
      const source = 'hello world';

      final result = buildHighlightedSource(
        source: source,
        matchOffsets: const [0],
        queryLength: 0,
        currentMatchIndex: 0,
      );

      expect(result, source);
    });

    test('wraps the single match with current-match markers', () {
      const source = 'hello world';

      final result = buildHighlightedSource(
        source: source,
        matchOffsets: const [6],
        queryLength: 5,
        currentMatchIndex: 0,
      );

      expect(result, 'hello ${_currentOpen}world$_currentClose');
    });

    test('wraps non-current match with normal markers', () {
      const source = 'foo bar foo';

      final result = buildHighlightedSource(
        source: source,
        matchOffsets: const [0, 8],
        queryLength: 3,
        currentMatchIndex: 1,
      );

      expect(
        result,
        '${_normalOpen}foo$_normalClose bar ${_currentOpen}foo$_currentClose',
      );
    });

    test('handles currentMatchIndex pointing at the first of many matches', () {
      const source = 'aa bb aa cc aa';
      final offsets = [0, 6, 12];

      final result = buildHighlightedSource(
        source: source,
        matchOffsets: offsets,
        queryLength: 2,
        currentMatchIndex: 0,
      );

      expect(
        result,
        '${_currentOpen}aa$_currentClose bb '
        '${_normalOpen}aa$_normalClose cc '
        '${_normalOpen}aa$_normalClose',
      );
    });

    test('handles match at the very start of source', () {
      const source = 'world hello';

      final result = buildHighlightedSource(
        source: source,
        matchOffsets: const [0],
        queryLength: 5,
        currentMatchIndex: 0,
      );

      expect(result, '${_currentOpen}world$_currentClose hello');
    });

    test('handles match at the very end of source', () {
      const source = 'hello world';

      final result = buildHighlightedSource(
        source: source,
        matchOffsets: const [6],
        queryLength: 5,
        currentMatchIndex: 0,
      );

      expect(result, 'hello ${_currentOpen}world$_currentClose');
    });

    test('skips matches that fall inside a fenced code block', () {
      const source = '```\nhello world\n```\nhello outside';

      // "hello" appears at offset 4 (inside fence) and at offset 20 (outside).
      final result = buildHighlightedSource(
        source: source,
        matchOffsets: const [4, 20],
        queryLength: 5,
        currentMatchIndex: 1,
      );

      // Offset 4 is inside the fence — no markers there.
      // Offset 20 is match index 1, so currentMatchIndex 1 → current markers.
      expect(result, contains('${_currentOpen}hello$_currentClose'));
      expect(result, isNot(contains('${_normalOpen}hello$_normalClose')));
      expect(
        result.indexOf(_normalOpen),
        -1,
        reason: 'no normal markers should appear',
      );
    });

    test('skips matches that fall inside an inline code span', () {
      const source = 'See `hello` for details. hello again.';
      // "hello" at offset 5 (inside backticks) and offset 25 (outside).

      final result = buildHighlightedSource(
        source: source,
        matchOffsets: const [5, 25],
        queryLength: 5,
        currentMatchIndex: 1,
      );

      expect(result, contains('${_currentOpen}hello$_currentClose'));
      // The inline-code match must NOT be wrapped.
      expect(result, contains('`hello`'));
    });

    test('preserves text between and around multiple matches exactly', () {
      const source = 'ab cd ab';

      final result = buildHighlightedSource(
        source: source,
        matchOffsets: const [0, 6],
        queryLength: 2,
        currentMatchIndex: 0,
      );

      // Text between matches must be unchanged.
      expect(result, contains(' cd '));
    });
  });

  group('findCodeRanges', () {
    test('returns empty list for source with no code regions', () {
      expect(findCodeRanges('plain text'), isEmpty);
    });

    test('identifies a fenced code block range', () {
      const source = 'before\n```\ncode\n```\nafter';
      final ranges = findCodeRanges(source);

      expect(ranges, hasLength(1));
      expect(ranges.first.$1, lessThanOrEqualTo(source.indexOf('```')));
      expect(
        ranges.first.$2,
        greaterThanOrEqualTo(source.lastIndexOf('```') + 3),
      );
    });

    test('identifies an inline code span', () {
      const source = 'use `foo` here';
      final ranges = findCodeRanges(source);

      expect(ranges, hasLength(1));
      final start = source.indexOf('`foo`');
      final end = start + '`foo`'.length;
      expect(ranges.first.$1, start);
      expect(ranges.first.$2, end);
    });

    test(
      'does not report inline code inside a fenced block as a separate range',
      () {
        const source = '```\n`inner`\n```';
        final ranges = findCodeRanges(source);

        // Only one range — the fence. The inner backtick pair is contained.
        expect(ranges, hasLength(1));
      },
    );
  });
}
