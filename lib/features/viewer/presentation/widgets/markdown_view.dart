import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart' as hl_dark;
import 'package:flutter_highlight/themes/atom-one-light.dart' as hl_light;
// `highlight` is a transitive dependency of `flutter_highlight`; see
// the rationale next to the matching import in `lib/main.dart`.
// ignore: depend_on_referenced_packages
import 'package:highlight/highlight.dart' as hi;
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/features/settings/domain/reading_settings.dart';
import 'package:markdown_viewer/features/viewer/application/markdown_extensions/math_syntax.dart';
import 'package:markdown_viewer/features/viewer/application/services/pdf_exporter.dart'
    show extractMermaidCodes;
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/admonition_view.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/footnote_view.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/math_view.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/mermaid_block.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/search_highlight_syntax.dart';
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

/// Estimates reading time in minutes at 200 words per minute.
///
/// Word count is derived from the raw markdown source — the handful of
/// syntax characters (`#`, `*`, …) counted as extra "words" introduce
/// at most a 2–3 % bias, which is well within the natural variance of
/// reading speed and not worth the cost of a full-text strip.
///
/// Returns at least 1 so even a one-line document shows "1 min read".
/// Pre-compiled whitespace regex for [_estimateReadingMinutes]. Kept
/// at file scope so a cache miss does not re-compile the pattern
/// every time a new document is opened.
final RegExp _wordSplitRegex = RegExp(r'\s+');

int _estimateReadingMinutes(Document document) {
  final cached = _readingMinutesCache[document];
  if (cached != null) return cached;
  final wordCount =
      document.source
          .trim()
          .split(_wordSplitRegex)
          .where((w) => w.isNotEmpty)
          .length;
  final minutes = (wordCount / 200).ceil();
  final result = minutes < 1 ? 1 : minutes;
  _readingMinutesCache[document] = result;
  return result;
}

/// Task-list checkbox builder used by the [CheckBoxConfig]
/// override the [MarkdownView] plugs into the live config.
///
/// The package's default `InputNode` computes its top padding
/// as `(parentStyleHeight / 2) - 12` — a constant that assumes
/// paragraph line height is at least 1.5 and that the host
/// never fiddles with `PConfig.textStyle.height`. Our reading
/// comfort settings do exactly that, which tips the top edge
/// into negative territory on the "compact" preset and hits
/// `RenderPadding`'s `padding.isNonNegative` assertion. A
/// custom builder sidesteps the broken math — we render our
/// own `Icon` with a fixed, always-positive padding that lines
/// up with the first line of prose regardless of the active
/// line-height multiplier.
Widget _buildTaskListCheckbox(bool checked) {
  return Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Icon(
      checked ? Icons.check_box : Icons.check_box_outline_blank,
      size: 18,
    ),
  );
}

/// Carries the active search state that [MarkdownView] needs to insert
/// highlight markers into the rendered source.
///
/// When [matchOffsets] is non-empty [MarkdownView] builds a modified
/// source string with PUA highlight markers and uses a search-mode
/// [MarkdownGenerator] that includes the two highlight [InlineSyntax]
/// and [SpanNodeGeneratorWithTag] entries. The match at
/// [currentMatchIndex] is rendered with a stronger background colour
/// ("current" highlight); every other match uses the "normal" colour.
class SearchHighlightState {
  const SearchHighlightState({
    required this.matchOffsets,
    required this.queryLength,
    required this.currentMatchIndex,
  });

  final List<int> matchOffsets;
  final int queryLength;
  final int currentMatchIndex;

  // Value equality so `widget.searchHighlight != oldWidget.searchHighlight`
  // checks — and any `Selector` / `updateShouldNotify` path we plug in
  // later — can short-circuit when the search state has not actually
  // changed. `matchOffsets` uses identity equality because the list is
  // immutable from the viewer's perspective (a new list is assigned on
  // every scan) and element-wise comparison would defeat the point on
  // documents with many matches.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHighlightState &&
          identical(matchOffsets, other.matchOffsets) &&
          queryLength == other.queryLength &&
          currentMatchIndex == other.currentMatchIndex);

  @override
  int get hashCode => Object.hash(
    identityHashCode(matchOffsets),
    queryLength,
    currentMatchIndex,
  );
}

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
/// Per-document cache for [extractMermaidCodes] output. Keyed by
/// [Document] identity so a given document is parsed at most once
/// across the many rebuilds that `markdown_widget` triggers during
/// normal use (theme flips, scroll ticks, reading-setting changes).
/// `Expando` entries are garbage-collected with the Document, so the
/// cache never pins an otherwise-dead object alive.
final Expando<List<String>> _mermaidCodesCache = Expando<List<String>>(
  'markdown_view.mermaidCodes',
);

/// Per-[Document] cache for [_estimateReadingMinutes]. The helper
/// splits the entire source on whitespace with a compiled regex —
/// cheap per call, but `MarkdownView.build` runs on every scroll
/// tick, theme change, and search-highlight refresh, so the word-
/// count scan would otherwise re-run tens of times per second on
/// an actively-read document. Expando keying on the Document
/// instance means a reload (new Document) naturally invalidates.
final Expando<int> _readingMinutesCache = Expando<int>(
  'markdown_view.readingMinutes',
);

/// Per-document cache for [extractFootnotes] output. Same rationale
/// as [_mermaidCodesCache].
final Expando<Map<String, String>> _footnotesCache =
    Expando<Map<String, String>>('markdown_view.footnotes');

class MarkdownView extends StatelessWidget {
  const MarkdownView({
    required this.document,
    this.controller,
    this.blockKeys,
    this.readingSettings = ReadingSettings.defaults,
    this.onLinkTap,
    this.onTocList,
    this.searchHighlight,
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

  /// Optional handler for link taps.
  ///
  /// Receives the raw `href` value from the markdown link. The
  /// caller is responsible for routing: anchor links (`#slug`)
  /// should scroll within the document; external `http(s)://`
  /// links should open a browser.
  ///
  /// When `null`, `markdown_widget`'s default behaviour fires —
  /// it calls `url_launcher` for every link — so callers that
  /// only care about external links can omit this.
  final void Function(String href)? onLinkTap;

  /// Invoked during every build with the list of headings
  /// `markdown_widget` discovered while constructing the rendered
  /// block list, in document order. Each [Toc] carries the
  /// `widgetIndex` of the heading's rendered widget — i.e. the
  /// index into the list that the surrounding render loop uses to
  /// look up its [blockKeys] entry.
  ///
  /// `ViewerScreen` uses this mapping to build its own
  /// `HeadingRef → widgetIndex` table so TOC navigation drives
  /// `Scrollable.ensureVisible` against the correct `GlobalKey`.
  /// Earlier versions of the viewer reused `HeadingRef.blockIndex`
  /// from the parser layer for this lookup, which quietly desynced
  /// as soon as `markdown_widget`'s block split (driven by its own
  /// regex + `encodeHtml: false`) diverged from the parser's block
  /// list (driven by `LineSplitter` + `encodeHtml: true`) —
  /// headings further down the document then either failed to
  /// scroll at all (out-of-range key lookup) or landed on the
  /// wrong block.
  ///
  /// The callback fires synchronously inside
  /// `MarkdownGenerator.buildWidgets`, so listeners must avoid
  /// calling `setState` directly; store the list in a plain field
  /// and read it on the next user interaction instead.
  final ValueChanged<List<Toc>>? onTocList;

  /// When non-null, enables inline search highlighting. [MarkdownView]
  /// inserts PUA markers around every match before rendering and uses a
  /// search-mode [MarkdownGenerator] that resolves those markers to
  /// coloured [TextSpan] backgrounds. The current match gets a stronger
  /// colour than the rest.
  final SearchHighlightState? searchHighlight;

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
        _buildPreConfig(theme, document),
        _buildTableConfig(),
        pConfigWithLineHeight,
        if (onLinkTap != null) LinkConfig(onTap: onLinkTap),
        // Custom task-list checkbox renderer. The package's
        // default `InputNode` applies
        // `EdgeInsets.fromLTRB(2, (parentStyleHeight / 2) - 12, 2, 0)`
        // which goes negative once we override paragraph line
        // height below the package's hard-coded 1.5 assumption
        // (our "compact" preset is 1.35, and even "standard"
        // at 1.55 is only 0.4 dp from the crash floor). The
        // assertion fires as soon as a GitHub-flavored task
        // list like `1. [x] Task` is parsed — the ForgeLM
        // roadmap hit it on the very first render. Providing
        // our own builder with a safe wrapper bypasses that
        // broken padding math entirely.
        const CheckBoxConfig(builder: _buildTaskListCheckbox),
      ],
    );

    // We render through `MarkdownGenerator.buildWidgets(...)` (rather
    // than handing the source to `MarkdownWidget`) because
    // `MarkdownWidget` does not accept an external `ScrollController`
    // — it owns a private one internally. Owning the controller at
    // this layer is what lets [ViewerScreen] drive the back-to-top
    // FAB and the reading-position bookmark feature.
    //
    // When search is active the source is pre-processed to insert PUA
    // highlight markers and a search-mode MarkdownGenerator that
    // resolves those markers is used instead of the shared static one.
    // Building a new MarkdownGenerator per active-search render is
    // acceptable: the object is pure configuration with no layout or
    // painting state, and rebuilds only happen when the user changes
    // the query or advances through matches.
    final highlight = searchHighlight;
    final activeHighlight =
        highlight != null && highlight.matchOffsets.isNotEmpty;

    // Pre-extract footnotes so the inline syntax can look up content
    // on tap. Cache per Document — same motivation as the mermaid
    // extraction cache above: `build` runs many times per document
    // and the extractor does a full line walk.
    final footnotes =
        _footnotesCache[document] ??= extractFootnotes(document.source);
    final hasFootnotes = footnotes.isNotEmpty;

    // Build the source string that will be fed to the markdown pipeline:
    // 1. Apply search-highlight PUA markers (against the original source
    //    so the pre-computed offsets stay valid).
    // 2. Strip footnote definition blocks so they do not appear as
    //    paragraph text — they are shown in popup sheets instead.
    var sourceToRender = document.source;
    if (activeHighlight) {
      sourceToRender = buildHighlightedSource(
        source: sourceToRender,
        matchOffsets: highlight.matchOffsets,
        queryLength: highlight.queryLength,
        currentMatchIndex: highlight.currentMatchIndex,
      );
    }
    if (hasFootnotes) {
      sourceToRender = stripFootnoteDefs(sourceToRender);
    }

    final scheme = theme.colorScheme;
    final needsCustomGenerator = activeHighlight || hasFootnotes;
    final generator =
        needsCustomGenerator
            ? MarkdownGenerator(
              blockSyntaxList: const [
                DisplayMathBlockSyntax(),
                md.AlertBlockSyntax(),
              ],
              inlineSyntaxList: [
                ...buildMathInlineSyntaxes(),
                if (hasFootnotes) ...buildFootnoteInlineSyntaxes(),
                if (activeHighlight) ...buildSearchHighlightInlineSyntaxes(),
              ],
              generators: [
                ...buildMathSpanNodeGenerators(),
                ...buildAdmonitionSpanNodeGenerators(),
                if (hasFootnotes)
                  ...buildFootnoteGenerators(
                    footnotes: footnotes,
                    color: scheme.primary,
                    onTap:
                        (id, content) =>
                            showFootnoteSheet(context, id, content),
                  ),
                if (activeHighlight)
                  ...buildSearchHighlightGenerators(
                    normalColor: scheme.primary.withAlpha(38),
                    currentColor: scheme.primary.withAlpha(110),
                  ),
              ],
            )
            : _markdownGenerator;

    // Forwarding `onTocList` through `buildWidgets` is what lets the
    // viewer map `HeadingRef`s to the exact `widgetIndex` of each
    // heading's rendered widget. `markdown_widget` runs its own parse
    // (`encodeHtml: false` + a split regex) that can disagree with
    // the parser-side block list in pathological-but-realistic cases
    // (frontmatter, HTML blocks, trailing whitespace runs) — ignoring
    // this callback silently desyncs TOC navigation.
    final widgets = generator.buildWidgets(
      sourceToRender,
      config: config,
      onTocList: onTocList,
    );

    // Wrap each rendered block in a `KeyedSubtree` whose `GlobalKey`
    // comes from the shared [blockKeys] map. The keys let
    // `Scrollable.ensureVisible` target the rendered widget without
    // any pixel measuring on our side — which is how the TOC drawer
    // jumps to a heading and the in-doc search lands on the block
    // that contains the current match.
    //
    // The map grows lazily via `putIfAbsent`: the viewer starts with
    // an empty (or partially-filled) map and every rebuild tops it
    // up to match the current widget count. This avoids a stale-key
    // class of bug where the parser's block count (which seeds the
    // map in earlier versions) disagreed with `widgets.length`,
    // leaving some widgets without a key and some keys without a
    // widget. Growing on demand against the authoritative
    // widget-count side keeps the two aligned by construction.
    final keys = blockKeys;
    final columnChildren = <Widget>[];

    // Reading-time estimate — sits above the first markdown block so
    // it scrolls away naturally as the user starts reading.
    columnChildren.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          context.l10n.viewerReadingTime(_estimateReadingMinutes(document)),
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    for (var i = 0; i < widgets.length; i += 1) {
      if (keys != null) {
        final key = keys.putIfAbsent(
          i,
          () => GlobalKey(debugLabel: 'doc-block-$i'),
        );
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
        textScaler: TextScaler.linear(
          mq.textScaler.scale(readingSettings.fontScale),
        ),
      ),
      child: SelectionArea(
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
      ),
    );
  }

  PreConfig _buildPreConfig(ThemeData theme, Document doc) {
    // Extract mermaid codes using our own parser path which
    // correctly preserves Unicode characters (em-dash, etc.).
    // markdown_widget's internal extraction corrupts em-dash
    // (U+2014) to colon (U+003A), breaking gantt task names.
    //
    // `_buildPreConfig` runs on every build (theme flips, scroll-
    // driven `markdown_widget` rebuilds, reading-settings changes,
    // etc.) and `extractMermaidCodes` is a full markdown parse. Cache
    // per-document via [Expando] so any given Document instance is
    // parsed at most once for its mermaid code list — entries are
    // collected automatically when the Document is GC'd.
    final cleanMermaidCodes =
        _mermaidCodesCache[doc] ??= extractMermaidCodes(doc.source);
    var mermaidIndex = 0;
    //
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Build the code text style from scratch — pulling fontSize from
    // the active body style so code respects the reading-comfort
    // scale, but explicitly NOT carrying a `color` over.
    //
    // `markdown_widget`'s `convertHiNodes` resolves each token's
    // final style via `theme[className].merge(textStyle)`; the merge
    // semantics let any non-null property on the second argument
    // override the matching property on the first. If `textStyle`
    // sets a colour, every per-token colour from
    // `atomOneLightTheme` / `atomOneDarkTheme` is silently flattened
    // into that single shade — which is why fenced blocks rendered
    // as monochrome before this constructor was switched away from
    // `baseBodyStyle.copyWith(color: scheme.onSurface)`. The
    // `styleNotMatched` value below provides the default colour for
    // tokens the highlighter does not classify (and for unnamed
    // fences) without ever reaching the per-token merge path.
    final baseBodyStyle =
        theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    final codeTextStyle = TextStyle(
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
      fontSize: baseBodyStyle.fontSize,
      height: 1.45,
    );

    final blockDecoration = BoxDecoration(
      color: isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      border: Border.all(color: scheme.outlineVariant, width: 0.5),
    );
    final hlTheme =
        isDark ? hl_dark.atomOneDarkTheme : hl_light.atomOneLightTheme;
    final fallbackStyle = TextStyle(color: scheme.onSurface);

    return PreConfig(
      decoration: blockDecoration,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      textStyle: codeTextStyle,
      styleNotMatched: fallbackStyle,
      theme: hlTheme,
      // Replace markdown_widget's default code-block renderer with a
      // whole-content one.
      //
      // The package's own `CodeBlockNode.build` splits the fence body
      // by newlines and calls `highlight.parse` on each line in
      // isolation. That breaks languages whose tokenisation needs
      // multi-line context — most visibly JSON, whose top-level mode
      // marks any non-whitespace outside `{…}` / `[…]` as illegal, so a
      // bare `"name": "value",` line produces a single unmatched node
      // and renders as monochrome text. YAML, Dart, Bash and friends are
      // line-oriented enough to survive the per-line path, which is why
      // only JSON looked broken before this change. Running the parser
      // once against the whole block applies the same logic but with
      // the full context intact.
      //
      // The mermaid branch moves here from the old `wrapper` because
      // `builder` takes over completely — `wrapper` is only consulted
      // on the default render path that we are now replacing. The same
      // `extractMermaidCodes` list (authoritative because it avoids
      // markdown_widget's em-dash-to-colon corruption) keeps feeding
      // `MermaidBlock` in document order.
      builder: (content, language) {
        if (language.toLowerCase() == 'mermaid') {
          final cleanCode =
              mermaidIndex < cleanMermaidCodes.length
                  ? cleanMermaidCodes[mermaidIndex]
                  : content;
          mermaidIndex += 1;
          return MermaidBlock(code: cleanCode);
        }
        final spans = _highlightFullBlock(
          source: content.trimRight(),
          language: language.isEmpty ? null : language,
          theme: hlTheme,
          fallback: fallbackStyle,
        );
        return Container(
          decoration: blockDecoration,
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text.rich(TextSpan(style: codeTextStyle, children: spans)),
          ),
        );
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

/// Parses [source] with `package:highlight` and returns a flat list of
/// [InlineSpan]s ready for a `Text.rich` body.
///
/// This is the whole-content replacement for `markdown_widget`'s own
/// `highLightSpans`, which splits by lines and highlights each in
/// isolation — see the long comment on `PreConfig.builder` above for
/// the JSON regression that motivated the override. When [language] is
/// null, the source is returned as a single unstyled span so unknown /
/// hint-less fences still render as plain monospace code.
///
/// Token-to-style resolution keeps the semantics of
/// `convertHiNodes` but drops its `style.merge` step: that merge
/// overrode every per-token colour from the active `flutter_highlight`
/// theme with whatever colour sat on the outer textStyle, which is
/// exactly the flattening we removed from `codeTextStyle` above. The
/// outer `Text.rich` passes `codeTextStyle` on the root `TextSpan`, so
/// font family, fontSize and height still propagate — the per-token
/// `TextSpan.style` only carries the colour (and italic for comments /
/// emphasis) and inherits everything else.
List<InlineSpan> _highlightFullBlock({
  required String source,
  required String? language,
  required Map<String, TextStyle> theme,
  required TextStyle fallback,
}) {
  if (language == null) {
    return [TextSpan(text: source, style: fallback)];
  }
  final hi.Result result;
  try {
    result = hi.highlight.parse(source, language: language);
  } catch (_) {
    return [TextSpan(text: source, style: fallback)];
  }
  final nodes = result.nodes ?? const <hi.Node>[];
  if (nodes.isEmpty) {
    return [TextSpan(text: source, style: fallback)];
  }

  final spans = <InlineSpan>[];
  var current = spans;
  final stack = <List<InlineSpan>>[];

  void traverse(hi.Node node, TextStyle? parentStyle) {
    final resolvedStyle =
        parentStyle ?? (node.className == null ? null : theme[node.className!]);
    final spanStyle = resolvedStyle ?? fallback;
    if (node.value != null) {
      current.add(TextSpan(text: node.value, style: spanStyle));
      return;
    }
    final children = node.children;
    if (children == null) return;
    final nested = <InlineSpan>[];
    current.add(TextSpan(children: nested, style: spanStyle));
    stack.add(current);
    current = nested;
    for (final child in children) {
      // Pass `null` on the recursive call — NOT the resolved parent
      // style. The wrapping TextSpan above already carries the
      // cascade for un-classed descendants, so passing `parentStyle`
      // here would shadow the child's own `theme[child.className]`
      // branch whenever the parent had a resolved style, forcing the
      // child to inherit the parent colour instead of its own
      // highlight theme entry. Fix produces correct nested highlight
      // colours (e.g. a `<span class="keyword">` inside a
      // `<code class="string">`) without flattening to the outer tone.
      // Reference: code-review CR-20260419-005 (+ perf side-effect
      // PR-20260419-025).
      traverse(child, null);
    }
    current = stack.isEmpty ? spans : stack.removeLast();
  }

  for (final node in nodes) {
    traverse(node, null);
  }
  return spans;
}
