import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_widget/markdown_widget.dart';

// ── Source preprocessing ─────────────────────────────────────────────

// Compiled once so every call to extractFootnotes avoids re-allocating
// the same pattern on every loop iteration.
final _defPattern = RegExp(r'^\[\^([^\]]+)\]:\s*(.*)');

/// Strips footnote definition blocks from [source] so they do not
/// appear in the rendered document body.
///
/// Definitions are surfaced via popup sheets when the user taps a
/// `[^id]` reference — see [showFootnoteSheet].
///
/// The regex matches a definition starter line (`[^id]: …`) plus any
/// immediately following continuation lines (indented ≥ 4 spaces or a
/// tab), covering both single-line and multi-paragraph footnotes.
String stripFootnoteDefs(String source) => source.replaceAll(
  RegExp(r'^\[\^[^\]]+\]:[ \t]*[^\n]*(?:\n[ \t]+[^\n]*)*', multiLine: true),
  '',
);

/// Extracts footnote definitions from raw markdown [source].
///
/// Returns a map of id → content string (the text that follows the
/// `[^id]:` marker). Multi-line continuation lines (indented ≥ 4
/// spaces) are joined with a single space.
///
/// Used by [buildFootnoteGenerators] to look up content when the user
/// taps a `[^id]` reference in the rendered document.
Map<String, String> extractFootnotes(String source) {
  final result = <String, String>{};
  final lines = source.split('\n');
  String? currentId;
  final buffer = StringBuffer();

  for (final line in lines) {
    final defMatch = _defPattern.firstMatch(line);
    if (defMatch != null) {
      if (currentId != null) {
        result[currentId] = buffer.toString().trim();
        buffer.clear();
      }
      currentId = defMatch.group(1)!;
      final first = defMatch.group(2) ?? '';
      if (first.isNotEmpty) buffer.write(first);
    } else if (currentId != null &&
        (line.startsWith('    ') || line.startsWith('\t'))) {
      final trimmed = line.trimLeft();
      if (trimmed.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(trimmed);
      }
    } else if (currentId != null) {
      result[currentId] = buffer.toString().trim();
      buffer.clear();
      currentId = null;
    }
  }
  if (currentId != null) {
    result[currentId] = buffer.toString().trim();
  }

  return result;
}

// ── InlineSyntax ──────────────────────────────────────────────────────

class _FootnoteRefSyntax extends md.InlineSyntax {
  // Matches `[^id]` anywhere in inline text.
  // Block-level definitions (`[^id]: …`) are stripped from the source
  // before the markdown pipeline runs, so this pattern only ever fires
  // on genuine references.
  _FootnoteRefSyntax() : super(r'\[\^([^\]]+)\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('footnoteRef', match.group(1)!));
    return true;
  }
}

// ── SpanNode ──────────────────────────────────────────────────────────

class _FootnoteRefSpanNode extends SpanNode {
  _FootnoteRefSpanNode({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  InlineSpan build() {
    final base = parentStyle?.fontSize ?? 14.0;
    return TextSpan(
      text: label,
      style: (parentStyle ?? const TextStyle()).copyWith(
        fontSize: base * 0.78,
        color: color,
        decoration: TextDecoration.underline,
        decorationColor: color,
      ),
      // A new recognizer per build is the standard SpanNode pattern —
      // SpanNode has no dispose lifecycle, so caching is not possible.
      recognizer: TapGestureRecognizer()..onTap = onTap,
    );
  }
}

// ── Bottom-sheet presenter ────────────────────────────────────────────

/// Shows a modal bottom sheet with the content of footnote [id].
///
/// [content] is the raw text extracted by [extractFootnotes]. It is
/// rendered as selectable plain text — sufficient for the short prose
/// typically found in markdown footnotes.
void showFootnoteSheet(BuildContext context, String id, String content) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // Allow the sheet to grow beyond half the screen so long footnotes
    // are not clipped. The inner content scrolls when it would overflow.
    isScrollControlled: true,
    builder: (_) => _FootnoteSheet(id: id, content: content),
  );
}

class _FootnoteSheet extends StatelessWidget {
  const _FootnoteSheet({required this.id, required this.content});

  final String id;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        // Cap at 90 % of the screen height so the sheet never covers the
        // entire viewport while still accommodating very long footnotes.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '[$id]',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                content.isEmpty ? '—' : content,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Factories ─────────────────────────────────────────────────────────

/// Returns the [md.InlineSyntax] that recognises `[^id]` footnote
/// references. Add to a `MarkdownGenerator`'s `inlineSyntaxList`.
List<md.InlineSyntax> buildFootnoteInlineSyntaxes() => [_FootnoteRefSyntax()];

/// Returns the [SpanNodeGeneratorWithTag] that renders `footnoteRef`
/// elements as tappable, underlined superscript-style labels.
///
/// [footnotes] — id → content map from [extractFootnotes].
/// [color]     — primary colour for the underlined reference label.
/// [onTap]     — called with (id, content) when the user taps.
List<SpanNodeGeneratorWithTag> buildFootnoteGenerators({
  required Map<String, String> footnotes,
  required Color color,
  required void Function(String id, String content) onTap,
}) => [
  SpanNodeGeneratorWithTag(
    tag: 'footnoteRef',
    generator:
        (el, _, __) => _FootnoteRefSpanNode(
          label: '[${el.textContent}]',
          color: color,
          onTap: () => onTap(el.textContent, footnotes[el.textContent] ?? ''),
        ),
  ),
];
