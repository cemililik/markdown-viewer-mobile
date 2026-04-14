import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart' as hl_dark;
import 'package:flutter_highlight/themes/atom-one-light.dart' as hl_light;
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_viewer/features/settings/domain/reading_settings.dart';
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
  const MarkdownView({
    required this.document,
    this.controller,
    this.blockKeys,
    this.readingSettings = ReadingSettings.defaults,
    super.key,
  });

  final Document document;

  /// Optional external [ScrollController] for the rendered list.
  ///
  /// Provided by [ViewerScreen] so the back-to-top FAB and the
  /// reading-position bookmark feature can read the offset and
  /// animate scroll position. When omitted the widget falls back
  /// to an internal controller — useful for tests and for any
  /// future caller that just wants to render a document without
  /// the scroll-bound features.
  final ScrollController? controller;

  /// Optional map from top-level block index to a `GlobalKey`
  /// that should wrap that block's rendered widget. Used by
  /// `ViewerScreen` to drive the TOC drawer's jump-to-heading
  /// via `Scrollable.ensureVisible` without having to measure
  /// offsets by hand.
  ///
  /// When the map is empty or `null`, every widget renders
  /// without any extra wrapping — unit tests and non-scrolling
  /// callers stay on the legacy path.
  final Map<int, GlobalKey>? blockKeys;

  /// Reading comfort settings (font scale, reading width cap,
  /// line height) that shape how the document renders. Held at
  /// this layer rather than read from a provider so
  /// `MarkdownView` remains testable without a `ProviderScope`
  /// and so the viewer can drive it from its own `ref.watch`.
  final ReadingSettings readingSettings;

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
    final basePConfig = base.p;
    final pConfigWithLineHeight = PConfig(
      textStyle: basePConfig.textStyle.copyWith(
        height: readingSettings.lineHeight.multiplier,
      ),
    );
    final config = base.copy(
      configs: [
        _buildPreConfig(theme),
        _buildTableConfig(),
        pConfigWithLineHeight,
      ],
    );

    // We render through `MarkdownGenerator.buildWidgets(...)` (rather
    // than handing the source to `MarkdownWidget`) because
    // `MarkdownWidget` does not accept an external `ScrollController`
    // — it owns a private one internally. Owning the controller at
    // this layer is what lets [ViewerScreen] drive the back-to-top
    // FAB and the reading-position bookmark feature.
    final widgets = _markdownGenerator.buildWidgets(
      document.source,
      config: config,
    );

    // Wrap each block widget in a KeyedSubtree if the viewer
    // handed us a GlobalKey for that index. The key lets
    // Scrollable.ensureVisible target the rendered widget
    // without any pixel measuring on our side — which is how
    // the TOC drawer jumps to a heading and the in-doc search
    // lands on the block that contains the current match.
    final keys = blockKeys;
    final columnChildren = <Widget>[];
    for (var i = 0; i < widgets.length; i += 1) {
      final key = keys?[i];
      if (key != null) {
        columnChildren.add(KeyedSubtree(key: key, child: widgets[i]));
      } else {
        columnChildren.add(widgets[i]);
      }
    }

    // The `Scrollbar` wrapper picks up the app-wide
    // `ScrollbarThemeData` (see `lib/app/theme.dart`): a thin
    // 4 dp thumb that fades in only while the reader is actively
    // scrolling. Hands the scroll position over via the same
    // [controller] [ViewerScreen] uses for back-to-top and
    // bookmark restore — no separate controller, no fight over
    // the scroll position source of truth.
    //
    // `SingleChildScrollView` + `Column` (instead of a
    // `ListView.builder`) is a deliberate choice for scrollbar
    // stability. `buildWidgets` above materialises the entire
    // document into a ready list of widgets — there is no lazy
    // win from a builder. A `ListView.builder` lays its children
    // out lazily as they enter the viewport, which means
    // `maxScrollExtent` grows on every new row and the scrollbar
    // thumb jumps up and down while the reader scrolls (observed
    // on iPhone). Forcing a single measurement pass here makes
    // the thumb behave like a reader expects — position = exact
    // fraction of the real document height — at the cost of a
    // one-time layout spike on very long documents. For a
    // phone-side markdown reader that tradeoff is strictly
    // correct; if a pathological document ever stalls the first
    // frame we can revisit with explicit `itemExtentBuilder` or
    // a slot-sliced variant, but typical docs are a few dozen
    // blocks where this cost is invisible.
    //
    // The `MediaQuery` override applies the reading font scale
    // on top of whatever the system's dynamic type setting
    // already provides, so a user who keeps the system default
    // (1.0x) and picks 1.15x in settings lands at 1.15x — and a
    // user with 1.3x system dynamic type and 1.15x in-app lands
    // at roughly 1.5x, matching other reader apps that stack
    // user preference over accessibility.
    //
    // The `ConstrainedBox` caps the column at the user's chosen
    // reading width on wide viewports. On a narrow phone every
    // `ReadingWidth` option collapses to the full viewport, so
    // the cap is only meaningful in landscape / tablet /
    // side-by-side layouts.
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(
          minScaleFactor: readingSettings.fontScale,
          maxScaleFactor: readingSettings.fontScale,
        ),
      ),
      child: Scrollbar(
        controller: controller,
        child: SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: readingSettings.width.maxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: columnChildren,
              ),
            ),
          ),
        ),
      ),
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
