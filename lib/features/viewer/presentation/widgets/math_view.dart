import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_viewer/features/viewer/application/markdown_extensions/math_syntax.dart';
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
    // Display math sits one Material 3 type step above body text —
    // `headlineSmall` matches the visual weight of a centred
    // equation without crowding the reading column. Inline math
    // inherits the body text size so it stays in line with the
    // surrounding paragraph. Both branches respect system font
    // scaling and any `MediaQuery.textScaler` overrides.
    final fontSize =
        _displayBlock
            ? theme.textTheme.headlineSmall?.fontSize ??
                theme.textTheme.bodyMedium?.fontSize
            : theme.textTheme.bodyMedium?.fontSize;
    final math = Math.tex(
      expression,
      mathStyle: mathStyle,
      textStyle: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: fontSize,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Inherit the reader's current body text size, then override only
    // what a code-like error label needs. The monospace stack runs
    // from most specific to least specific — `'monospace'` is a
    // valid system alias on Android and would short-circuit the
    // fallback walk if placed first. See the matching comment in
    // `markdown_view.dart`.
    final baseBodyStyle =
        theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    final text = Text(
      expression,
      style: baseBodyStyle.copyWith(
        fontFamily: 'JetBrains Mono',
        fontFamilyFallback: const [
          'Menlo',
          'Consolas',
          'Roboto Mono',
          'monospace',
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
///
/// The math widget is wrapped in [_IntrinsicSafe] so `RenderTable`
/// column sizing (and anything else that probes intrinsic widths)
/// does not crash: `flutter_math_fork` uses a `LayoutBuilder`
/// subclass that throws on intrinsic queries.
///
/// Earlier revisions also wrapped the child in
/// `SelectionContainer.disabled` to keep `SelectionArea` from walking
/// into the math subtree for boundingBox sorts. That caused the
/// enclosing `_ScrollableSelectionContainerDelegate` to fire a
/// `!_selectionStartsInScrollable` assertion on every rebuild — each
/// new `SelectionContainer.disabled` re-registers with the
/// `MultiSelectableSelectionContainerDelegate`, which then dispatches
/// an init-selection event into a scrollable that was already holding
/// a drag-selection flag. Dropping the wrapper is safe because the
/// [_IntrinsicSafe] proxy above already prevents the `boundingBoxes`
/// layout race at its root cause.
class InlineMathSpanNode extends SpanNode {
  InlineMathSpanNode(this.expression);

  final String expression;

  @override
  InlineSpan build() => WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: _IntrinsicSafe(child: MathView.inline(expression: expression)),
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
    child: _IntrinsicSafe(child: MathView.display(expression: expression)),
  );
}

/// Proxy widget that short-circuits intrinsic dimension queries.
///
/// `flutter_math_fork` builds its render tree through a `LayoutBuilder`
/// subclass (`_RenderLayoutBuilderPreserveBaseline`) that explicitly
/// throws when asked for `computeMaxIntrinsicWidth` / `Height`. Flutter
/// widgets that size children via intrinsics — most importantly
/// `Table` with the default `IntrinsicColumnWidth` used by
/// `markdown_widget` for pipe tables — surface this as a hard crash
/// the moment a cell contains inline math (`| ... | $\alpha$ |`).
///
/// This wrapper reports a zero intrinsic width / height so the
/// enclosing layout can compute column widths without descending into
/// the math subtree. At real layout time the math widget is still
/// given the cell's actual constraints and paints normally; the
/// intrinsic answer only influences column-width allocation, and a
/// table with text in other columns still gets a sensible width from
/// those cells.
class _IntrinsicSafe extends SingleChildRenderObjectWidget {
  const _IntrinsicSafe({required Widget super.child});

  @override
  _RenderIntrinsicSafe createRenderObject(BuildContext context) =>
      _RenderIntrinsicSafe();
}

class _RenderIntrinsicSafe extends RenderProxyBox {
  @override
  double computeMinIntrinsicWidth(double height) => 0;
  @override
  double computeMaxIntrinsicWidth(double height) => 0;
  @override
  double computeMinIntrinsicHeight(double width) => 0;
  @override
  double computeMaxIntrinsicHeight(double width) => 0;
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
