import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart' as hl_dark;
import 'package:flutter_highlight/themes/atom-one-light.dart' as hl_light;
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_viewer/features/viewer/application/markdown_extensions/math_syntax.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/admonition_view.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/math_view.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/mermaid_block.dart';
import 'package:markdown_widget/markdown_widget.dart';

/// Pre-built `MarkdownGenerator` reused for every render of every
/// [MarkdownView] instance.
///
/// The generator is pure and immutable: it owns three stateless
/// configuration lists ([md.AlertBlockSyntax], the math block /
/// inline syntaxes, and the math + admonition span node
/// generators). Recreating it on every `build` would allocate four
/// new lists and a new `MarkdownGenerator` per frame and per
/// scroll, for no behavioural benefit. Caching it once at
/// load time keeps the hot path allocation-free.
///
/// The list literal includes the math block syntax, GitHub alert
/// block syntax (admonitions), the inline math syntax, the math
/// span node generators, and the admonition span node generators
/// in the order the parser and visitor expect:
///
/// 1. **Block syntaxes** run first during parsing. Display math
///    must therefore live here, not in `inlineSyntaxList`, so a
///    user who writes `$$ … $$` mid-paragraph gets literal text
///    instead of a layout-disrupting inline `WidgetSpan`.
/// 2. **Inline syntaxes** run during paragraph processing. Only
///    single-dollar `$ … $` math is inline by construction.
/// 3. **Generators** are written into the visitor's tag→builder
///    map; ours are additive on top of the package's defaults
///    (links, emphasis, lists, …) — see the `WidgetVisitor`
///    constructor in `markdown_widget`.
final MarkdownGenerator _markdownGenerator = MarkdownGenerator(
  blockSyntaxList: const [DisplayMathBlockSyntax(), md.AlertBlockSyntax()],
  inlineSyntaxList: buildMathInlineSyntaxes(),
  generators: [
    ...buildMathSpanNodeGenerators(),
    ...buildAdmonitionSpanNodeGenerators(),
  ],
);

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
/// - LaTeX math via `flutter_math_fork`: `$ … $` inline (via
///   [InlineMathSyntax]) and `$$ … $$` display math (via
///   [DisplayMathBlockSyntax]) rendered by the `SpanNodeGenerator`s
///   in [buildMathSpanNodeGenerators]. Malformed input renders an
///   inline error placeholder without crashing the document.
/// - GitHub-style admonitions (`> [!NOTE]`, `> [!WARNING]`, …) via
///   `package:markdown`'s built-in [md.AlertBlockSyntax] on the
///   parser side plus [buildAdmonitionSpanNodeGenerators] on the
///   rendering side, producing themed [AdmonitionView] containers.
/// - Mermaid diagrams via a sandboxed `HeadlessInAppWebView` —
///   fenced code blocks tagged `mermaid` are intercepted by
///   [PreConfig.builder] and rendered through [MermaidBlock], which
///   talks to the `mermaidRendererProvider` port. See ADR-0005 for
///   the rendering contract and `docs/standards/security-standards.md`
///   §WebView Rules for the sandbox configuration.
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

    // `MarkdownConfig.copy(configs: [...])` is a **merge**, not a
    // replacement: it writes each entry in the supplied list into
    // the existing tag→config map and then constructs a new
    // MarkdownConfig from the full merged set. Passing our
    // PreConfig + TableConfig therefore overrides only those two
    // slots while every other dark variant (HConfig,
    // BlockquoteConfig, PConfig, …) pre-loaded by
    // `MarkdownConfig.darkConfig` survives unchanged. See
    // `MarkdownConfig.copy` in
    // `package:markdown_widget/config/configs.dart`.
    final config = base.copy(
      configs: [_buildPreConfig(theme), _buildTableConfig()],
    );

    return MarkdownWidget(
      data: document.source,
      config: config,
      markdownGenerator: _markdownGenerator,
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
      // Font resolution rules on every Flutter platform (Android,
      // iOS, desktop, web): the engine tries `fontFamily` first and
      // only walks `fontFamilyFallback` if nothing matches.
      // `'monospace'` is a valid system alias on Android, so putting
      // it first would cause the engine to stop there and never
      // consider the specific faces below. The stack must therefore
      // run from most specific to least specific, with the generic
      // alias at the end.
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
      // `wrapper` (not `builder`) is the right hook for a
      // selective override: markdown_widget builds the default
      // syntax-highlighted code container first, then passes it
      // and the (code, language) tuple through the wrapper. Using
      // `builder` would force us to re-implement the highlight
      // rendering for every non-mermaid block. With `wrapper` we
      // intercept only `mermaid` and let everything else fall
      // through unchanged.
      wrapper: (child, code, language) {
        if (language.toLowerCase() == 'mermaid') {
          return MermaidBlock(code: code);
        }
        return child;
      },
    );
  }

  /// Wraps every rendered markdown table in a horizontal
  /// [SingleChildScrollView] so multi-column tables remain
  /// reachable on narrow mobile screens. Without this the default
  /// `Table` widget clips any column that cannot fit the reading
  /// column width, and there is no way for the user to reach the
  /// hidden cells.
  ///
  /// `ClampingScrollPhysics` cancels the iOS overscroll bounce on
  /// the horizontal axis so it does not fight with the outer
  /// `ListView`'s vertical scroll — otherwise dragging diagonally
  /// feels like a tug-of-war between the two scrollables.
  TableConfig _buildTableConfig() {
    return TableConfig(
      wrapper:
          (table) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: table,
          ),
    );
  }
}
