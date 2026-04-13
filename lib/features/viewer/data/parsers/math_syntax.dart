import 'package:markdown/markdown.dart' as md;

/// HTML-like tag name emitted for a **display** math block such as
/// `$$ E = mc^2 $$`. Consumed by the matching `SpanNodeGenerator` in
/// the presentation layer.
const String mathBlockTag = 'math-block';

/// HTML-like tag name emitted for an **inline** math expression such
/// as `$E = mc^2$` inside a paragraph.
const String mathInlineTag = 'math-inline';

/// Matches display math fenced with `$$ … $$`, across line breaks.
///
/// Registered **before** [InlineMathSyntax] in the inline syntax list
/// so that `$$E=mc^2$$` is recognised as one display math element
/// instead of two empty inline math matches surrounding `E=mc^2`.
///
/// The pattern uses `[\s\S]*?` (with the default single-line mode)
/// so it matches across newlines — multi-line display math works
/// because `package:markdown`'s paragraph parser concatenates the
/// paragraph body before inline syntaxes run over it.
///
/// The captured expression is stored as a child [md.Text] node so
/// the widget visitor can retrieve the raw TeX source later.
class DisplayMathSyntax extends md.InlineSyntax {
  DisplayMathSyntax() : super(r'\$\$([\s\S]+?)\$\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final expression = match.group(1) ?? '';
    if (expression.trim().isEmpty) {
      return false;
    }
    final element = md.Element.text(mathBlockTag, expression.trim());
    parser.addNode(element);
    return true;
  }
}

/// Matches inline math fenced with `$ … $` within a single line.
///
/// Rules:
///
/// - The body cannot contain a literal `$` or a newline (anything
///   that does forces the reader to write `\$` or use a display
///   block).
/// - Empty `$$` is rejected so a stray pair of dollars in prose is
///   treated as literal text.
/// - Must be used **after** [DisplayMathSyntax] so `$$ … $$` wins.
///
/// Captured TeX source is stored on a child [md.Text] node for the
/// widget visitor.
class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax() : super(r'\$([^$\n]+?)\$');

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

/// Convenience list returned in the order `package:markdown` should
/// try the syntaxes. Display before inline — see class doc for the
/// reasoning. Exposed as a single source of truth so the parser
/// factory and the widget-tree factory never disagree on order.
const List<md.InlineSyntax Function()> mathSyntaxFactories = [
  _buildDisplay,
  _buildInline,
];

md.InlineSyntax _buildDisplay() => DisplayMathSyntax();
md.InlineSyntax _buildInline() => InlineMathSyntax();

/// Constructs the math syntax list in the canonical order.
List<md.InlineSyntax> buildMathInlineSyntaxes() => [
  for (final factory in mathSyntaxFactories) factory(),
];
