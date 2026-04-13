import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart' as hl_dark;
import 'package:flutter_highlight/themes/atom-one-light.dart' as hl_light;
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_viewer/features/viewer/data/parsers/math_syntax.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/admonition_view.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/math_view.dart';
import 'package:markdown_widget/markdown_widget.dart';

/// Renders a parsed [Document] using `markdown_widget`.
///
/// `markdown_widget` already covers most of the surface we need for
/// Phase 1: CommonMark + GitHub-Flavoured Markdown (tables, task
/// lists, footnotes, strikethrough), inline code, links, blockquotes,
/// and **syntax-highlighted fenced code blocks** via the bundled
/// `flutter_highlight` themes. We do not need a custom block builder
/// for any of those.
///
/// On top of the package defaults this widget adds:
///
/// - Material-3-aware [PreConfig]: code blocks sit on
///   `colorScheme.surfaceContainer*` instead of the package's
///   hard-coded greys, and the syntax theme is `atom-one-light` /
///   `atom-one-dark` from `flutter_highlight`.
/// - LaTeX math via `flutter_math_fork`: `$…$` inline and
///   `$$…$$` display math are recognised by [buildMathInlineSyntaxes]
///   and rendered by the `SpanNodeGenerator`s in
///   [buildMathSpanNodeGenerators]. Malformed input renders an
///   inline error placeholder without crashing the document.
/// - GitHub-style admonitions (`> [!NOTE]`, `> [!WARNING]`, …) via
///   `package:markdown`'s built-in [md.AlertBlockSyntax] on the
///   parser side plus [buildAdmonitionSpanNodeGenerators] on the
///   rendering side, producing themed [AdmonitionView] containers.
///
/// A custom block builder for mermaid lands in the next phase by
/// extending the same [MarkdownGenerator] with one more
/// `SpanNodeGeneratorWithTag` entry for fenced `mermaid` blocks.
class MarkdownView extends StatelessWidget {
  const MarkdownView({required this.document, super.key});

  final Document document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base =
        theme.brightness == Brightness.dark
            ? MarkdownConfig.darkConfig
            : MarkdownConfig.defaultConfig;
    final config = base.copy(configs: [_buildPreConfig(theme)]);

    return MarkdownWidget(
      data: document.source,
      config: config,
      markdownGenerator: MarkdownGenerator(
        blockSyntaxList: const [md.AlertBlockSyntax()],
        inlineSyntaxList: buildMathInlineSyntaxes(),
        generators: [
          ...buildMathSpanNodeGenerators(),
          ...buildAdmonitionSpanNodeGenerators(),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  PreConfig _buildPreConfig(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Start from the active body text style so code blocks inherit
    // the same fontSize baseline the rest of the reading column uses
    // (respecting system font scaling), then override the parts that
    // are specific to code: the monospace stack, a slightly taller
    // line height, and the code colour.
    final baseBodyStyle =
        theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    final codeTextStyle = baseBodyStyle.copyWith(
      // Font resolution rules on every Flutter platform (Android, iOS,
      // desktop, web): the engine tries `fontFamily` first and only
      // walks `fontFamilyFallback` if nothing matches. `'monospace'`
      // is a valid system alias on Android, so putting it first would
      // cause the engine to stop there and never consider the
      // specific faces below. The stack must therefore run from most
      // specific to least specific, with the generic alias at the end.
      //
      // `'JetBrains Mono'` uses the canonical family name with a
      // space — matches the font when we eventually bundle it.
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: const [
        'Menlo',
        'Consolas',
        'Roboto Mono',
        'monospace',
      ],
      height: 1.45,
      color: scheme.onSurface,
    );

    return PreConfig(
      decoration: BoxDecoration(
        color:
            isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      textStyle: codeTextStyle,
      styleNotMatched: TextStyle(color: scheme.onSurface),
      theme: isDark ? hl_dark.atomOneDarkTheme : hl_light.atomOneLightTheme,
    );
  }
}
