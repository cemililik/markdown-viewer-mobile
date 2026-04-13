import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_viewer/features/viewer/data/parsers/math_syntax.dart';
import 'package:markdown_widget/markdown_widget.dart';

/// Renders a single LaTeX math expression via `flutter_math_fork`.
///
/// Two forms:
///
/// - [MathView.inline]  — `MathStyle.text` with the surrounding
///   paragraph's font size, meant to sit inside a `WidgetSpan`
/// - [MathView.display] — `MathStyle.display`, centred, horizontally
///   scrollable so a long matrix or equation does not clip the
///   reading column
///
/// On a parse or build error the widget shows a compact inline
/// placeholder that uses [ColorScheme.errorContainer] so a broken
/// equation never blanks out the rest of the document and the
/// reader can still see where the malformed source sits.
class MathView extends StatelessWidget {
  const MathView.inline({required this.expression, super.key})
    : mathStyle = MathStyle.text,
      _displayBlock = false;

  const MathView.display({required this.expression, super.key})
    : mathStyle = MathStyle.display,
      _displayBlock = true;

  /// Raw TeX source, without the surrounding `$` or `$$` delimiters.
  final String expression;

  /// Passed through to `Math.tex.mathStyle`.
  final MathStyle mathStyle;

  /// `true` for display-mode equations, `false` for inline.
  final bool _displayBlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final math = Math.tex(
      expression,
      mathStyle: mathStyle,
      textStyle: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: _displayBlock ? 18 : theme.textTheme.bodyMedium?.fontSize,
      ),
      onErrorFallback:
          (error) => _MathErrorFallback(
            expression: expression,
            displayBlock: _displayBlock,
          ),
    );

    if (!_displayBlock) {
      return math;
    }

    // Wrap display math in a horizontal scroll so long matrices and
    // equations do not clip the reading column. Padding matches
    // `MarkdownView`'s code block margins for visual rhythm.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Center(child: math),
      ),
    );
  }
}

class _MathErrorFallback extends StatelessWidget {
  const _MathErrorFallback({
    required this.expression,
    required this.displayBlock,
  });

  final String expression;
  final bool displayBlock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Text(
      expression,
      style: TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const [
          'JetBrainsMono',
          'Menlo',
          'Consolas',
          'Roboto Mono',
        ],
        color: scheme.onErrorContainer,
      ),
      softWrap: !displayBlock,
      overflow: TextOverflow.visible,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: text,
    );
  }
}

/// `SpanNode` that wraps an inline math [md.Element] into a
/// `WidgetSpan` containing an inline `MathView`.
class InlineMathSpanNode extends SpanNode {
  InlineMathSpanNode(this.expression);

  final String expression;

  @override
  InlineSpan build() => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: MathView.inline(expression: expression),
  );
}

/// `SpanNode` that wraps a display math [md.Element] into a
/// `WidgetSpan` containing a block `MathView`. The parent paragraph
/// still renders as `Text.rich`, so wrapping the display math in a
/// `WidgetSpan` keeps markdown_widget's line layout happy while
/// still letting the actual math widget take its natural height.
class BlockMathSpanNode extends SpanNode {
  BlockMathSpanNode(this.expression);

  final String expression;

  @override
  InlineSpan build() => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: MathView.display(expression: expression),
  );
}

/// Builds the two `SpanNodeGeneratorWithTag` entries that the
/// viewer's `MarkdownGenerator` needs to turn math AST elements into
/// `MathView`s. Exposing a single factory keeps the tag names
/// consistent across the parser layer and the widget layer — both
/// sides read them from [mathInlineTag] / [mathBlockTag] in
/// `math_syntax.dart`.
List<SpanNodeGeneratorWithTag> buildMathSpanNodeGenerators() {
  return [
    SpanNodeGeneratorWithTag(
      tag: mathInlineTag,
      generator:
          (element, config, visitor) =>
              InlineMathSpanNode(_collectPlainText(element)),
    ),
    SpanNodeGeneratorWithTag(
      tag: mathBlockTag,
      generator:
          (element, config, visitor) =>
              BlockMathSpanNode(_collectPlainText(element)),
    ),
  ];
}

/// Walks the element's children and concatenates every [md.Text]
/// node it finds. Our math inline syntaxes emit a single text child
/// containing the TeX source, but going through a walker keeps the
/// code robust to a future syntax that builds a nested AST.
String _collectPlainText(md.Element element) {
  final buffer = StringBuffer();
  for (final child in element.children ?? const <md.Node>[]) {
    if (child is md.Text) {
      buffer.write(child.text);
    } else if (child is md.Element) {
      buffer.write(_collectPlainText(child));
    }
  }
  return buffer.toString();
}
