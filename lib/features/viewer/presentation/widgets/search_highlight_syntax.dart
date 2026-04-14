import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_widget/markdown_widget.dart';

// ── Marker constants ──────────────────────────────────────────────────
//
// Unicode Private-Use Area code points U+E000–U+E003. These are
// guaranteed never to appear in user-authored markdown source, so they
// act as zero-collision sentinels that survive the markdown block parser
// intact and are invisible to users if they somehow appear in plain text.

const String _kNormalOpen = '\uE000';
const String _kNormalClose = '\uE001';
const String _kCurrentOpen = '\uE002';
const String _kCurrentClose = '\uE003';

const String _kNormalTag = 'search-match';
const String _kCurrentTag = 'search-match-current';

// ── Source mutation ───────────────────────────────────────────────────

/// Inserts PUA highlight markers around every match in [source].
///
/// The match at [currentMatchIndex] receives "current" markers
/// (`_kCurrentOpen`/`_kCurrentClose`) and will be rendered with a
/// stronger background colour. Every other match gets "normal" markers.
///
/// Matches that overlap a fenced code block or an inline code span are
/// silently skipped — `markdown_widget`'s block-level code renderer runs
/// before inline syntaxes, so any marker characters inside a code fence
/// would appear as literal PUA glyphs in the highlighted source block
/// rather than triggering the search-highlight `InlineSyntax`.
///
/// Returns the original [source] unchanged when [matchOffsets] is empty
/// or [queryLength] is zero.
String buildHighlightedSource({
  required String source,
  required List<int> matchOffsets,
  required int queryLength,
  required int currentMatchIndex,
}) {
  if (matchOffsets.isEmpty || queryLength == 0) return source;

  final codeRanges = _findCodeRanges(source);
  final buffer = StringBuffer();
  var cursor = 0;

  for (var i = 0; i < matchOffsets.length; i++) {
    final start = matchOffsets[i];
    final end = start + queryLength;

    if (_overlapsAnyRange(start, end, codeRanges)) continue;

    buffer.write(source.substring(cursor, start));
    final isCurrent = i == currentMatchIndex;
    buffer.write(isCurrent ? _kCurrentOpen : _kNormalOpen);
    buffer.write(source.substring(start, end));
    buffer.write(isCurrent ? _kCurrentClose : _kNormalClose);
    cursor = end;
  }

  buffer.write(source.substring(cursor));
  return buffer.toString();
}

/// Returns `[start, end)` ranges for every fenced code block and
/// inline code span in [source].
///
/// Used by [buildHighlightedSource] to skip matches that fall inside
/// code regions, where the `InlineSyntax` never runs.
List<(int, int)> findCodeRanges(String source) => _findCodeRanges(source);

List<(int, int)> _findCodeRanges(String source) {
  final ranges = <(int, int)>[];

  // Fenced code blocks: ``` or ~~~ at the start of a line.
  // Pair up open/close fences (odd = open, even = close).
  final fencePattern = RegExp(r'^(`{3,}|~{3,})[^\n]*$', multiLine: true);
  final fences = fencePattern.allMatches(source).toList();
  for (var i = 0; i + 1 < fences.length; i += 2) {
    ranges.add((fences[i].start, fences[i + 1].end));
  }

  // Inline code spans: `...` — only those not already inside a fence.
  final inlinePattern = RegExp(r'`[^`\n]+`');
  for (final match in inlinePattern.allMatches(source)) {
    if (!_overlapsAnyRange(match.start, match.end, ranges)) {
      ranges.add((match.start, match.end));
    }
  }

  return ranges;
}

bool _overlapsAnyRange(int start, int end, List<(int, int)> ranges) {
  for (final r in ranges) {
    if (start < r.$2 && end > r.$1) return true;
  }
  return false;
}

// ── InlineSyntax ──────────────────────────────────────────────────────

class _HighlightMatchSyntax extends md.InlineSyntax {
  _HighlightMatchSyntax() : super('\uE000([^\uE001]*)\uE001');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text(_kNormalTag, match.group(1) ?? ''));
    return true;
  }
}

class _CurrentHighlightMatchSyntax extends md.InlineSyntax {
  // Registered before _HighlightMatchSyntax so the current-match
  // markers are consumed first if both syntaxes happen to start at
  // the same position (they never do in practice, but ordering is
  // important for correctness).
  _CurrentHighlightMatchSyntax() : super('\uE002([^\uE003]*)\uE003');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text(_kCurrentTag, match.group(1) ?? ''));
    return true;
  }
}

// ── SpanNode ──────────────────────────────────────────────────────────

class _HighlightSpanNode extends SpanNode {
  _HighlightSpanNode(this.text, this.backgroundColor);

  final String text;
  final Color backgroundColor;

  @override
  InlineSpan build() => TextSpan(
    text: text,
    style: (parentStyle ?? const TextStyle()).copyWith(
      backgroundColor: backgroundColor,
    ),
  );
}

// ── Factory functions ─────────────────────────────────────────────────

/// Returns the two `InlineSyntax` instances that recognise normal and
/// current-match PUA markers. Must be added to a `MarkdownGenerator`'s
/// `inlineSyntaxList` alongside the math syntaxes.
List<md.InlineSyntax> buildSearchHighlightInlineSyntaxes() => [
  _CurrentHighlightMatchSyntax(),
  _HighlightMatchSyntax(),
];

/// Returns the two `SpanNodeGeneratorWithTag` entries that render
/// highlighted match spans. Pass theme-derived colours so the
/// highlights adapt to light, dark, and sepia themes.
///
/// Typical values:
/// - [normalColor]  — `colorScheme.primary.withAlpha(38)`  (≈ 15 % opacity)
/// - [currentColor] — `colorScheme.primary.withAlpha(102)` (≈ 40 % opacity)
List<SpanNodeGeneratorWithTag> buildSearchHighlightGenerators({
  required Color normalColor,
  required Color currentColor,
}) => [
  SpanNodeGeneratorWithTag(
    tag: _kNormalTag,
    generator: (el, _, __) => _HighlightSpanNode(el.textContent, normalColor),
  ),
  SpanNodeGeneratorWithTag(
    tag: _kCurrentTag,
    generator: (el, _, __) => _HighlightSpanNode(el.textContent, currentColor),
  ),
];
