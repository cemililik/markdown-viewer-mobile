import 'package:markdown/markdown.dart' as md;

/// HTML-like tag name emitted for a **display** math block such as
/// `$$ E = mc^2 $$`. Consumed by the matching `SpanNodeGenerator` in
/// the presentation layer.
const String mathBlockTag = 'math-block';

/// HTML-like tag name emitted for an **inline** math expression such
/// as `$E = mc^2$` inside a paragraph.
const String mathInlineTag = 'math-inline';

/// `BlockSyntax` that recognises display math fenced with `$$ … $$`.
///
/// Two forms are accepted:
///
/// 1. **Single line** — `$$E = mc^2$$` on its own line.
/// 2. **Multi line** — an opening `$$` on its own line, body content
///    spanning one or more lines, then a closing `$$` on its own
///    line:
///
/// ```text
/// $$
/// \frac{a}{b}
/// $$
/// ```
///
/// The earlier revision used an `InlineSyntax` for display math.
/// That worked when the block sat alone on a paragraph but produced
/// ugly layout if a user accidentally embedded `$$ … $$`
/// mid-paragraph: the resulting display math `WidgetSpan` has its
/// own vertical padding and centring, which threw line height
/// calculations off and pushed surrounding text apart. A real
/// `BlockSyntax` makes display math a top-level list item in the
/// document tree and refuses to match anything that is not on its
/// own line, which is the semantically correct behaviour.
///
/// Empty bodies (`$$ $$` or `$$\n\n$$`) are rejected so a stray pair
/// of `$$`s in prose stays as literal text.
class DisplayMathBlockSyntax extends md.BlockSyntax {
  const DisplayMathBlockSyntax();

  /// Pattern used by [canParse] — matches any line that begins with
  /// `$$` after optional leading whitespace. The full classification
  /// (single-line vs multi-line, body extraction) is done in [parse]
  /// for clarity.
  static final RegExp _opening = RegExp(r'^\s*\$\$');

  @override
  RegExp get pattern => _opening;

  @override
  bool canParse(md.BlockParser parser) {
    return _opening.hasMatch(parser.current.content);
  }

  @override
  md.Node? parse(md.BlockParser parser) {
    final firstLine = parser.current.content.trimRight();
    final firstTrimmed = firstLine.trimLeft();

    // ---- Single-line form: `$$ … $$` on one line ------------------
    if (firstTrimmed.length >= 4 &&
        firstTrimmed.startsWith(r'$$') &&
        firstTrimmed.endsWith(r'$$')) {
      final body = firstTrimmed.substring(2, firstTrimmed.length - 2).trim();
      parser.advance();
      if (body.isEmpty) {
        // Refuse to emit an empty math block — let the line fall
        // through to the next syntax (paragraph), where it will
        // render as literal `$$$$` text.
        return null;
      }
      return md.Element.text(mathBlockTag, body);
    }

    // ---- Multi-line form: `$$` on its own line, then body, then `$$`
    if (firstTrimmed != r'$$') {
      // A line that starts with `$$` but is neither the single-line
      // form nor a bare `$$` opener (e.g. `$$ inline garbage`) is
      // not display math at all. Bail and let downstream syntaxes
      // decide what to do with the line.
      return null;
    }
    parser.advance();

    final bodyLines = <String>[];
    while (!parser.isDone) {
      final line = parser.current.content;
      if (line.trim() == r'$$') {
        parser.advance();
        break;
      }
      bodyLines.add(line);
      parser.advance();
    }
    // If the closing `$$` was missing before EOF we still emit the
    // body that was collected — the renderer's onErrorFallback will
    // then show a placeholder. Returning null here would silently
    // drop the user's content, which is a worse failure mode.

    final body = bodyLines.join('\n').trim();
    if (body.isEmpty) {
      return null;
    }
    return md.Element.text(mathBlockTag, body);
  }
}

/// `InlineSyntax` that recognises inline math fenced with `$ … $`
/// inside a single line of running prose.
///
/// Rules:
///
/// - The body cannot contain a literal `$` or a newline. Anything
///   that does forces the user to escape the dollar (`\$`) or use a
///   display block.
/// - An empty body is rejected so a stray `$$` does not leak into
///   prose as inline math.
/// - The closing `$` must NOT be immediately followed by a digit.
///   Without this rule, `$5 and $10` would match as a single inline
///   math element wrapping the body `5 and ` — turning currency
///   into a math run. The negative lookahead `(?!\d)` keeps prose
///   like `Pay me $5 and $10 in change.` as plain text.
/// - Display math (`$$ … $$`) is handled by [DisplayMathBlockSyntax]
///   which runs at block-parse time, before inline syntaxes get a
///   chance to see anything. Mid-paragraph `$$ … $$` will therefore
///   not match this syntax either — it stays as literal text, which
///   is the right behaviour because display math has no inline form.
class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax() : super(r'\$([^$\n]+?)\$(?!\d)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final expression = match.group(1) ?? '';
    if (expression.trim().isEmpty) {
      return false;
    }
    final element = md.Element.text(mathInlineTag, expression);
    parser.addNode(element);
    return true;
  }
}

/// Constructs the math block syntaxes. There is currently only one
/// — display math — but the factory exists so the wiring code in
/// `MarkdownView` can always splat the result without caring about
/// the count.
List<md.BlockSyntax> buildMathBlockSyntaxes() => const [
  DisplayMathBlockSyntax(),
];

/// Constructs the math inline syntaxes. Display math now lives in
/// the block syntaxes, so this list contains only the single-dollar
/// `$ … $` case. The factory keeps the layering shape consistent
/// with [buildMathBlockSyntaxes].
List<md.InlineSyntax> buildMathInlineSyntaxes() => [InlineMathSyntax()];
