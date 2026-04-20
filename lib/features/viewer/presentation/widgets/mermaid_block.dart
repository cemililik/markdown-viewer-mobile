import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/features/viewer/application/markdown_extensions/admonition.dart';
import 'package:markdown_viewer/features/viewer/application/mermaid_renderer_provider.dart';
import 'package:markdown_viewer/features/viewer/application/mermaid_utils.dart';
import 'package:markdown_viewer/features/viewer/domain/services/mermaid_renderer.dart';
import 'package:markdown_viewer/features/viewer/presentation/screens/diagram_fullscreen_screen.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/admonition_view.dart';

/// Renders a single mermaid fenced code block as a PNG bitmap.
///
/// Hooked into [MarkdownView] via `PreConfig.wrapper`. The widget
/// owns no parsing logic — it reads the active Material 3
/// [ColorScheme], builds a mermaid `%%{init: …}%%` directive so
/// the rendered diagram inherits the same palette as the rest of
/// the app, and hands both strings to the
/// [mermaidRendererProvider].
///
/// Flipping the app theme rebuilds the widget, fires a fresh
/// render against a cache key that bakes the directive in, and
/// the renderer's LRU keeps the previous palette's output in its
/// own slot — toggling back is instant.
///
/// If the user's source already carries its own
/// `%%{init: …}%%` directive, the ColorScheme-derived override is
/// suppressed — user intent wins.
///
/// The error placeholder reuses [paletteForAdmonition] with
/// [AdmonitionKind.warning] so a failed mermaid diagram has the
/// same visual language as a `> [!WARNING]` admonition. Pending
/// state shows a low-key spinner sized to roughly a typical
/// diagram footprint so the surrounding text does not jump when
/// the bitmap arrives.
class MermaidBlock extends ConsumerStatefulWidget {
  const MermaidBlock({required this.code, super.key});

  /// The raw mermaid source as it appeared inside the fenced code
  /// block, with surrounding fence markers and the language tag
  /// already stripped by `markdown_widget`.
  final String code;

  @override
  ConsumerState<MermaidBlock> createState() => _MermaidBlockState();
}

class _MermaidBlockState extends ConsumerState<MermaidBlock> {
  Future<MermaidRenderResult>? _future;
  String? _renderedDirective;
  String? _renderedThemeCss;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeRerender();
  }

  @override
  void didUpdateWidget(covariant MermaidBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _renderedDirective = null;
      _renderedThemeCss = null;
      _maybeRerender();
    }
  }

  void _maybeRerender() {
    final scheme = Theme.of(context).colorScheme;
    final directive =
        _sourceHasOwnDirective(widget.code)
            ? ''
            : buildMermaidInitDirective(scheme);
    final themeCss = buildMermaidThemeCss(scheme);
    // Re-render only when EITHER the init directive or the theme
    // CSS changes. A theme flip produces a fresh `themeCss` even
    // for a user-authored-directive source (where `directive` stays
    // empty), so tracking both halves keeps ER / gitgraph paints
    // in sync with the active palette.
    if (_future != null &&
        _renderedDirective == directive &&
        _renderedThemeCss == themeCss) {
      return;
    }
    _renderedDirective = directive;
    _renderedThemeCss = themeCss;
    _future = ref
        .read(mermaidRendererProvider)
        .render(widget.code, initDirective: directive, themeCss: themeCss);
  }

  static bool _sourceHasOwnDirective(String source) {
    // Skip any leading YAML frontmatter block before checking for a
    // %%{init: directive, using the same shared helper that the renderer
    // uses when deciding where to splice the init directive.
    final scanFrom = frontmatterEndIndex(source) ?? 0;
    return source.substring(scanFrom).trimLeft().startsWith('%%{init:');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MermaidRenderResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _MermaidPlaceholder();
        }
        final result = snapshot.data;
        if (result is MermaidRenderSuccess) {
          return _MermaidImage(
            pngBytes: result.pngBytes,
            width: result.width,
            height: result.height,
          );
        }
        final detail =
            result is MermaidRenderFailure
                ? result.message
                : snapshot.error?.toString();
        return _MermaidErrorPlaceholder(detail: detail);
      },
    );
  }
}

/// Builds a mermaid init directive string that threads the active
/// Material 3 [scheme] through every theme variable mermaid honours,
/// so flowchart / sequence / class / state / gantt / ER diagrams
/// all read as if the app drew them itself.
///
/// The returned string is intended to be prepended to a mermaid
/// source by the renderer; it always ends with a newline so the
/// real diagram content starts on a fresh line.
///
/// `theme: "base"` is pinned because it is the only mermaid preset
/// that honours user-supplied `themeVariables`. The `default` and
/// `dark` presets silently drop most overrides.
///
/// Light vs dark mode is expressed entirely through [scheme]: both
/// `scheme.onPrimaryContainer` and the other `on*` roles already
/// flip between light and dark palettes, so every task-text /
/// contrast-sensitive variable in the map below picks up the
/// right value automatically without a separate `Brightness`
/// argument.
String buildMermaidInitDirective(ColorScheme scheme) {
  String hex(Color color) {
    final r = (color.r * 255).round() & 0xff;
    final g = (color.g * 255).round() & 0xff;
    final b = (color.b * 255).round() & 0xff;
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  final onPrimaryContainer = hex(scheme.onPrimaryContainer);
  final onSecondaryContainer = hex(scheme.onSecondaryContainer);
  final onTertiaryContainer = hex(scheme.onTertiaryContainer);
  final primaryContainer = hex(scheme.primaryContainer);
  final secondaryContainer = hex(scheme.secondaryContainer);
  final tertiaryContainer = hex(scheme.tertiaryContainer);
  final primary = hex(scheme.primary);
  final secondary = hex(scheme.secondary);
  final tertiary = hex(scheme.tertiary);
  final surface = hex(scheme.surface);
  final surfaceContainer = hex(scheme.surfaceContainer);
  final surfaceContainerHigh = hex(scheme.surfaceContainerHigh);
  final onSurface = hex(scheme.onSurface);
  final outline = hex(scheme.outline);
  final outlineVariant = hex(scheme.outlineVariant);
  final error = hex(scheme.error);
  final errorContainer = hex(scheme.errorContainer);
  final onErrorContainer = hex(scheme.onErrorContainer);
  final onPrimary = hex(scheme.onPrimary);
  final onSecondary = hex(scheme.onSecondary);
  final onTertiary = hex(scheme.onTertiary);
  final onError = hex(scheme.onError);

  // Task text on active gantt bars has to read on top of
  // `primaryContainer`; on dark mode that container is darker than
  // mid-grey so the task text wants to be lighter, and vice versa.
  // Keeping it as `onPrimaryContainer` already handles that.
  final taskTextOnBar = onPrimaryContainer;

  final variables = <String, String>{
    // ── Core / shared across every diagram type ──────────────────
    'background': surface,
    'primaryColor': primaryContainer,
    'primaryTextColor': onPrimaryContainer,
    'primaryBorderColor': primary,
    'secondaryColor': secondaryContainer,
    'secondaryTextColor': onSecondaryContainer,
    'secondaryBorderColor': secondary,
    'tertiaryColor': tertiaryContainer,
    'tertiaryTextColor': onTertiaryContainer,
    'tertiaryBorderColor': tertiary,
    'lineColor': outline,
    'textColor': onSurface,
    'titleColor': onSurface,
    'mainBkg': surfaceContainer,
    'errorBkgColor': errorContainer,
    'errorTextColor': onErrorContainer,

    // ── Flowchart ────────────────────────────────────────────────
    'nodeBkg': primaryContainer,
    'nodeBorder': primary,
    'nodeTextColor': onPrimaryContainer,
    'clusterBkg': surfaceContainerHigh,
    'clusterBorder': outlineVariant,
    'edgeLabelBackground': surfaceContainer,
    'defaultLinkColor': outline,

    // ── Sequence diagram ─────────────────────────────────────────
    'actorBkg': primaryContainer,
    'actorBorder': primary,
    'actorTextColor': onPrimaryContainer,
    'actorLineColor': outline,
    'signalColor': onSurface,
    'signalTextColor': onSurface,
    'labelBoxBkgColor': secondaryContainer,
    'labelBoxBorderColor': secondary,
    'labelTextColor': onSecondaryContainer,
    'loopTextColor': onSurface,
    'noteBkgColor': tertiaryContainer,
    'noteBorderColor': tertiary,
    'noteTextColor': onTertiaryContainer,
    'activationBkgColor': secondaryContainer,
    'activationBorderColor': secondary,
    'sequenceNumberColor': onPrimaryContainer,

    // ── State diagram ────────────────────────────────────────────
    'labelColor': onSurface,
    'altBackground': surfaceContainerHigh,
    'compositeBackground': surfaceContainer,
    'compositeTitleBackground': primaryContainer,
    'compositeBorder': outlineVariant,

    // ── Gantt ────────────────────────────────────────────────────
    'sectionBkgColor': surfaceContainer,
    'altSectionBkgColor': surfaceContainerHigh,
    'gridColor': outlineVariant,
    'taskBkgColor': primaryContainer,
    'taskBorderColor': primary,
    'taskTextColor': taskTextOnBar,
    'taskTextLightColor': onPrimaryContainer,
    'taskTextDarkColor': onPrimaryContainer,
    'taskTextClickableColor': onPrimaryContainer,
    'doneTaskBkgColor': secondaryContainer,
    'doneTaskBorderColor': secondary,
    'activeTaskBkgColor': tertiaryContainer,
    'activeTaskBorderColor': tertiary,
    'critBkgColor': errorContainer,
    'critBorderColor': error,
    'todayLineColor': error,

    // ── ER diagram ───────────────────────────────────────────────
    //
    // Mermaid v11's ER renderer lives in `async function EM(t,e)`
    // (inside the bundled `mermaid.min.js`) and destructures its
    // attribute-row background + stroke colours from `themeVariables`
    // as:
    //     let {rowEven: a, rowOdd: s, nodeBorder: l} = n;
    // then emits `<path class="row-rect-odd" fill=${s}>` /
    // `<path class="row-rect-even" fill=${a}>` directly — the
    // `attributeBackgroundColorOdd/Even` variables that earlier
    // mermaid versions honoured are declared for backwards
    // compatibility but NEVER read by the v11 renderer, so setting
    // them has no effect. Pinning `rowOdd` / `rowEven` to our
    // Material 3 surface tones is the path that actually reaches
    // the SVG fill and makes dark-theme ER rows readable.
    'rowOdd': surfaceContainer,
    'rowEven': surfaceContainerHigh,
    // Retained for older mermaid builds that might swap in through
    // asset hot-reload; harmless no-ops on v11.
    'attributeBackgroundColorOdd': surfaceContainer,
    'attributeBackgroundColorEven': surfaceContainerHigh,
    'relationColor': outline,
    'relationLabelColor': onSurface,
    'relationLabelBackground': surfaceContainer,

    // ── Gitgraph ─────────────────────────────────────────────────
    //
    // Mermaid renders gitgraph branch lines with the CSS
    // `.commit-branchN { stroke: ${commitLineColor ?? lineColor}; }`.
    // The `lineColor` value we share across every diagram type is
    // `outline` — deliberately muted so flowchart / sequence edges
    // do not dominate the reading column. On gitgraph against a
    // black reading surface that muted stroke disappears into the
    // background. `commitLineColor` is the gitgraph-specific
    // override the renderer checks before falling back to
    // `lineColor`, so pinning it to `onSurface` gives gitgraph the
    // high-contrast line it needs without dragging every other
    // diagram type into heavy-weight edges.
    'commitLineColor': onSurface,
    // Commit labels (`init`, `add parser`, …) — readable on both
    // light and dark surfaces since the mermaid default pill uses
    // `commitLabelBackground` behind the text.
    'commitLabelColor': onSurface,
    'commitLabelBackground': surfaceContainer,
    'tagLabelColor': onPrimaryContainer,
    'tagLabelBackground': primaryContainer,
    'tagLabelBorder': primary,
    // Per-branch commit-circle / arrow / branch-label-box fills.
    // Mermaid v11's gitgraph stylesheet emits, per branch index u:
    //   .commit${u}      { stroke: ${git${u}}; fill: ${git${u}}; }
    //   .arrow${u}       { stroke: ${git${u}}; }
    //   .branch-label${u}{ fill:   ${gitBranchLabel${u}}; }
    // The `base` theme defaults `git0..git7` to primaryColor /
    // secondaryColor / tertiaryColor (and hue-rotated variants),
    // then `updateColors()` applies `Ye(c, 25)` — a 25 % darken —
    // to every slot because we do not pass `darkMode: true`. In
    // the app's dark Material palette those primary/secondary/
    // tertiary defaults are already the `*Container` dark tones,
    // so the extra darken pushes the commit dots and branch-label
    // boxes to near-invisible on the dark reading surface (the
    // symptom the user reported). Pinning each slot to a saturated
    // *core* tone (`primary` / `secondary` / `tertiary` / `error`)
    // lands the post-`Ye` value inside the visible mid-tone band
    // on both light AND dark backgrounds — and it keeps branch
    // colours distinguishable rather than collapsing onto a single
    // hue.
    'git0': primary,
    'git1': secondary,
    'git2': tertiary,
    'git3': error,
    'git4': primary,
    'git5': secondary,
    'git6': tertiary,
    'git7': error,
    // Branch-name text sits inside the coloured `git${u}` box, so
    // pair each slot with its `on*` counterpart for contrast.
    // `gitInv${u}` is mermaid's "inverted commit highlight" fill
    // (cherry-pick markers, highlighted commits) — same contrast
    // pairing works there too.
    'gitBranchLabel0': onPrimary,
    'gitBranchLabel1': onSecondary,
    'gitBranchLabel2': onTertiary,
    'gitBranchLabel3': onError,
    'gitBranchLabel4': onPrimary,
    'gitBranchLabel5': onSecondary,
    'gitBranchLabel6': onTertiary,
    'gitBranchLabel7': onError,
    'gitInv0': onPrimary,
    'gitInv1': onSecondary,
    'gitInv2': onTertiary,
    'gitInv3': onError,
    'gitInv4': onPrimary,
    'gitInv5': onSecondary,
    'gitInv6': onTertiary,
    'gitInv7': onError,

    // ── Mindmap ───────────────────────────────────────────────────
    //
    // Mermaid's mindmap renderer cycles its branch fills through
    // a `cScale<i>` palette and reads the matching label colours
    // from `cScaleLabel<i>`. The defaults from `theme: "base"`
    // produce washed-out pastels that are nearly unreadable on
    // the dark Material 3 surface, so we override the first
    // twelve slots (mindmaps rarely go past three levels — the
    // extra slots cover wide root nodes with many children) with
    // the project's container palette plus their matching `on*`
    // text colours.
    //
    // The cycle is `primary → secondary → tertiary → surfaceHigh`
    // so that no single branch family dominates and every level
    // has paired text contrast that flips with light / dark
    // theme automatically. The fourth slot is the neutral
    // surface high so a fourth-level branch reads as "more of
    // the same hierarchy" rather than as a fourth distinct
    // semantic colour.
    'cScale0': primaryContainer,
    'cScale1': secondaryContainer,
    'cScale2': tertiaryContainer,
    'cScale3': surfaceContainerHigh,
    'cScale4': primaryContainer,
    'cScale5': secondaryContainer,
    'cScale6': tertiaryContainer,
    'cScale7': surfaceContainerHigh,
    'cScale8': primaryContainer,
    'cScale9': secondaryContainer,
    'cScale10': tertiaryContainer,
    'cScale11': surfaceContainerHigh,
    'cScaleLabel0': onPrimaryContainer,
    'cScaleLabel1': onSecondaryContainer,
    'cScaleLabel2': onTertiaryContainer,
    'cScaleLabel3': onSurface,
    'cScaleLabel4': onPrimaryContainer,
    'cScaleLabel5': onSecondaryContainer,
    'cScaleLabel6': onTertiaryContainer,
    'cScaleLabel7': onSurface,
    'cScaleLabel8': onPrimaryContainer,
    'cScaleLabel9': onSecondaryContainer,
    'cScaleLabel10': onTertiaryContainer,
    'cScaleLabel11': onSurface,
    // Mindmap also uses `cScalePeer<i>` for the connecting
    // lines between a branch and its children. Routing those
    // through the matching `*Border*` (primary / secondary / …)
    // colours keeps the line tied to the visual family of the
    // branch it sprouts from.
    'cScalePeer0': primary,
    'cScalePeer1': secondary,
    'cScalePeer2': tertiary,
    'cScalePeer3': outline,
    'cScalePeer4': primary,
    'cScalePeer5': secondary,
    'cScalePeer6': tertiary,
    'cScalePeer7': outline,
    'cScalePeer8': primary,
    'cScalePeer9': secondary,
    'cScalePeer10': tertiary,
    'cScalePeer11': outline,
    // Bump the global mermaid font from its default 14 px to
    // 16 px so mindmap labels stay legible after the
    // `useMaxWidth: true` SVG gets scaled into a phone column.
    // 16 px is the same baseline the project uses for body
    // text, so mindmap text matches the surrounding paragraph
    // sizing instead of looking smaller.
    'fontSize': '16px',
  };

  // Mermaid accepts JSON syntax inside the init directive, so we
  // can let `jsonEncode` do all the escaping work and avoid hand-
  // rolled string concatenation edge cases.
  //
  // The directive only has to thread the colour palette through —
  // mermaid's default `htmlLabels: true` and `useMaxWidth: true`
  // are kept because the sandbox WebView renders them faithfully
  // (CSS, foreignObject, font metrics all work) and the native
  // screenshot path captures whatever the browser paints.
  // 'classic' suppresses the per-diagram-type decorative icons added in
  // Mermaid v11 (the mindmap icon in particular looks like a bomb/starburst
  // and is confusing in both the viewer and PDF output).
  //
  // `themeCSS` is NOT passed through the init pragma — mermaid v11
  // silently drops it from `%%{init: …}%%` payloads (only the
  // `mermaid.initialize({...})` config-time override is honoured).
  // The theme stylesheet is instead installed via
  // `buildMermaidThemeCss` + the sandbox's `__setMermaidTheme` JS
  // hook on every render. See `mermaid_html_template.dart`.
  final payload = jsonEncode({
    'theme': 'base',
    'look': 'classic',
    'themeVariables': variables,
  });
  return '%%{init: $payload}%%\n';
}

/// Mermaid CSS overrides for diagram types whose `themeVariables`
/// path leaks through to default browser colours on the `data:`
/// URI render.
///
/// The ER renderer in mermaid v11 ignores the documented
/// `attributeBackgroundColorOdd` / `attributeBackgroundColorEven`
/// theme variables entirely — they are declared on every theme
/// class for backwards compatibility but never threaded into the
/// SVG output. Instead the ER renderer draws each attribute row
/// as a `<foreignObject>` containing `<span>` elements with the
/// classes `attribute-type` / `attribute-name` / `attribute-keys`
/// / `attribute-comment`, and the surrounding browser default
/// paints those spans on a solid-white HTML backplate. Entity
/// title text is rendered the same way under the `name` class.
///
/// The HTML template (`mermaid_html_template.dart`) already
/// forces `foreignObject` backgrounds to transparent so the
/// underlying SVG rect (themed via `mainBkg`) shows through.
/// This CSS handles the other half — text colour — by targeting
/// both the SVG `<text>` variant (older mermaid builds that did
/// not use HTML labels) and the HTML `foreignObject` content.
///
/// The returned stylesheet is installed in the sandbox document
/// head by `window.__setMermaidTheme` before every render; the
/// string is also part of [MermaidRenderer.render]'s cache key so
/// light / dark variants of the same diagram do not reuse each
/// other's bitmap. Public so `MermaidBlock` can derive it from
/// the active `ColorScheme` without duplicating the hex colour
/// plumbing inside `buildMermaidInitDirective`.
String buildMermaidThemeCss(ColorScheme scheme) {
  String hex(Color color) {
    final r = (color.r * 255).round() & 0xff;
    final g = (color.g * 255).round() & 0xff;
    final b = (color.b * 255).round() & 0xff;
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  return _mermaidThemeCssInternal(
    surfaceContainer: hex(scheme.surfaceContainer),
    surfaceContainerHigh: hex(scheme.surfaceContainerHigh),
    onSurface: hex(scheme.onSurface),
    outline: hex(scheme.outline),
  );
}

String _mermaidThemeCssInternal({
  required String surfaceContainer,
  required String surfaceContainerHigh,
  required String onSurface,
  required String outline,
}) {
  // Scoped narrowly to ER + gitgraph selectors so user-defined
  // `classDef color:#XXX` overrides in flowcharts / class diagrams
  // / state diagrams are NOT stomped.
  //
  // - ER entity title text lives inside `<g class="label name">`;
  //   attribute rows inside `<g class="label attribute-type">` /
  //   `…attribute-name` / `…attribute-keys` / `…attribute-comment`.
  //   The `[class~="name"]` form explicitly matches "name" as a
  //   whitespace-separated class token, which is the contract SVG
  //   class attributes use, so a user's Flow label that happens
  //   to contain the substring "name" cannot accidentally match.
  //   Same rationale for the attribute-* variants.
  //
  // - ER row-rect paths (`row-rect-odd` / `row-rect-even`) are
  //   themed via `rowOdd` / `rowEven` theme variables in the init
  //   pragma — v11 reads those directly from `themeVariables` when
  //   building the inline SVG `fill="…"`. CSS override here is
  //   unnecessary for the row backgrounds. Kept commented for
  //   discoverability.
  //
  // - Gitgraph branch lines are `<path class="branch">` with
  //   `stroke: commitLineColor ?? lineColor` in the generated
  //   stylesheet. `commitLineColor` is honoured by the init
  //   pragma, but a belt-and-suspenders CSS override makes sure
  //   the dark-theme stroke cannot be undone by any later-loaded
  //   stylesheet mermaid may append for feature diagrams.
  return '[class~="name"].label, [class~="name"].label foreignObject div, '
      '[class~="name"].label foreignObject span '
      '{ color: $onSurface !important; fill: $onSurface !important; } '
      '[class~="attribute-type"].label, '
      '[class~="attribute-name"].label, '
      '[class~="attribute-keys"].label, '
      '[class~="attribute-comment"].label, '
      '[class~="attribute-type"].label foreignObject *, '
      '[class~="attribute-name"].label foreignObject *, '
      '[class~="attribute-keys"].label foreignObject *, '
      '[class~="attribute-comment"].label foreignObject * '
      '{ color: $onSurface !important; fill: $onSurface !important; '
      'background: transparent !important; '
      'background-color: transparent !important; } '
      '.entityBox { fill: $surfaceContainer !important; '
      'stroke: $outline !important; } '
      '.relationshipLine { stroke: $outline !important; '
      'fill: none !important; } '
      '.relationshipLabelBox { fill: $surfaceContainerHigh !important; } '
      '.branch { stroke: $onSurface !important; } '
      '.commit-id, .commit-msg '
      '{ fill: $onSurface !important; color: $onSurface !important; }';
}

/// Pan+zoom container for a rasterised mermaid diagram.
///
/// The WebView hands us PNG bytes plus the diagram's natural CSS
/// pixel dimensions (computed by the browser at layout time, so
/// they reflect the real text-wrapped, font-metric-aware footprint
/// — not whatever flutter_svg might recompute against its own
/// fonts). We size the widget against those dimensions so the
/// diagram keeps its intrinsic proportions, and wrap the bitmap in
/// an [InteractiveViewer] for pinch-zoom + two-finger pan.
///
/// Layout strategy:
///
/// - Try to fill column width first (`displayWidth = columnWidth`,
///   `displayHeight = displayWidth / aspectRatio`).
/// - If the resulting height exceeds [_maxHeightFraction] of the
///   screen height (a tall vertical flowchart, a long class
///   diagram, etc.), invert the calculation: pin height to the
///   cap and recompute width so the aspect ratio stays intact.
///   The diagram then sits centred in the column with horizontal
///   slack on either side, leaving the reader enough whitespace
///   above and below to land an outer-scroll gesture.
///
/// A small tonal icon button in the top-left fades in whenever the
/// underlying `TransformationController` has moved off the identity
/// matrix. Tapping it runs a short [Matrix4Tween] animation back
/// to identity — a one-tap recovery if the user zooms + pans the
/// diagram out of frame.
class _MermaidImage extends StatefulWidget {
  const _MermaidImage({
    required this.pngBytes,
    required this.width,
    required this.height,
  });

  final Uint8List pngBytes;
  final double width;
  final double height;

  /// Fraction of the screen height a single mermaid diagram is
  /// allowed to claim. Picked so even tall diagrams leave roughly
  /// 40% of the viewport above / below for the user to land an
  /// outer-scroll gesture.
  static const double _maxHeightFraction = 0.6;

  /// Floor on the rendered diagram box height so the overlay
  /// chrome (fullscreen button in the top-right, reset button in
  /// the top-left) always fits inside the paintable region. Very
  /// wide-aspect diagrams (left-to-right flowcharts, single-line
  /// gantt rows, edge-type galleries) used to be sized purely from
  /// their natural aspect ratio, which shrank the box to 40–60 px
  /// tall and clipped the 44 × 44 dp buttons off the top and
  /// bottom. 88 px = 8 dp top padding + 44 dp button + 8 dp
  /// breathing room + 28 dp for the image itself; the `BoxFit.
  /// contain` inside keeps the diagram centred vertically so the
  /// extra height reads as padding, not distortion.
  static const double _minBoxHeight = 88;

  @override
  State<_MermaidImage> createState() => _MermaidImageState();
}

class _MermaidImageState extends State<_MermaidImage>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transform;
  late final AnimationController _resetController;
  Animation<Matrix4>? _resetAnimation;
  bool _isTransformed = false;

  @override
  void initState() {
    super.initState();
    _transform = TransformationController();
    _transform.addListener(_onTransformChanged);
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(_MermaidImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.pngBytes, widget.pngBytes) ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height) {
      // A new bitmap arrived (re-render or theme flip) — discard the
      // previous pan/zoom so the fresh diagram is shown at identity.
      // Stop any running recenter animation first so _applyResetFrame
      // cannot overwrite the identity matrix after we set it.
      _resetAnimation?.removeListener(_applyResetFrame);
      _resetAnimation = null;
      _resetController.stop();
      _transform.value = Matrix4.identity();
    }
  }

  void _onTransformChanged() {
    final transformed = !_transform.value.isIdentity();
    if (transformed != _isTransformed) {
      setState(() => _isTransformed = transformed);
    }
  }

  void _resetTransform() {
    // Reduce-motion collapses the 300 ms ease — the fullscreen
    // route's reset button already honours this gate; mirror it
    // here so the inline diagram matches. With animations disabled
    // we apply the identity transform directly and skip the tween.
    // Reference: performance-review PR-20260419-002.
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      _resetController.stop();
      _resetAnimation?.removeListener(_applyResetFrame);
      _resetAnimation = null;
      _transform.value = Matrix4.identity();
      return;
    }
    final tween = Matrix4Tween(
      begin: _transform.value.clone(),
      end: Matrix4.identity(),
    );
    _resetAnimation?.removeListener(_applyResetFrame);
    _resetAnimation = tween.animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    )..addListener(_applyResetFrame);
    _resetController
      ..reset()
      ..forward();
  }

  void _applyResetFrame() {
    final animation = _resetAnimation;
    if (animation == null) {
      return;
    }
    _transform.value = animation.value;
  }

  /// Pushes the dedicated fullscreen route with the already-rendered
  /// PNG bytes + dimensions. `context.push` (not `go`) is deliberate
  /// — popping back lands on the viewer at the exact scroll offset
  /// the reader left, so the diagram excursion does not break the
  /// reading flow. The inline transform state is preserved because
  /// the fullscreen screen owns its own `TransformationController`.
  void _openFullscreen() {
    HapticFeedback.selectionClick().ignore();
    context.push(
      DiagramRoute.location(),
      extra: DiagramFullscreenArgs(
        pngBytes: widget.pngBytes,
        width: widget.width,
        height: widget.height,
      ),
    );
  }

  @override
  void dispose() {
    _resetAnimation?.removeListener(_applyResetFrame);
    _resetController.dispose();
    _transform
      ..removeListener(_onTransformChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final aspectRatio =
        widget.width > 0 && widget.height > 0
            ? widget.width / widget.height
            : 16 / 9;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDiagramHeight = screenHeight * _MermaidImage._maxHeightFraction;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      // Exclude the entire diagram subtree from the enclosing
      // `SelectionArea` (wired in `markdown_view.dart`). The inline
      // `InteractiveViewer` that powers the pan/zoom gesture
      // produces a `RenderFractionalTranslation` whose layout is
      // not deterministically finished by the time the selection
      // pipeline walks the render tree — touching the diagram
      // while a selection exists would fire two distinct framework
      // assertions:
      //
      //   1. `RenderBox was not laid out` on
      //      `_SelectionContainerState.getTransformTo` →
      //      `_compareScreenOrder` (screen-order sort during
      //      selection init).
      //   2. `!_selectionStartsInScrollable` on
      //      `_ScrollableSelectionContainerDelegate
      //      .handleSelectionEdgeUpdate` when the drag-select edge
      //      crosses into a nested scrollable that did not see the
      //      start event.
      //
      // `math_view.dart` hit the first assertion via a different
      // route (`LayoutBuilder` intrinsic probe) and chose to wrap
      // in `_IntrinsicSafe` instead of disabling selection, because
      // math is an inline span that rebuilds on every paragraph
      // render — a `SelectionContainer.disabled` around an inline
      // span would register / unregister on every rebuild and
      // trip the same scrollable assertion. Mermaid blocks are
      // different: they are a stateful widget with a stable
      // position in the tree, so the disabled container registers
      // exactly once with the selection delegate and the re-register
      // churn does not happen. Rendered mermaid images have no
      // selectable text anyway — diagrams reach the user as raster
      // bytes.
      child: SelectionContainer.disabled(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columnWidth = constraints.maxWidth;
            var displayWidth = columnWidth;
            var displayHeight = displayWidth / aspectRatio;
            if (displayHeight > maxDiagramHeight) {
              displayHeight = maxDiagramHeight;
              displayWidth = displayHeight * aspectRatio;
            }
            // Floor the box height so the fullscreen + reset buttons
            // always fit. Wide-aspect diagrams (Edge types, Node
            // shapes, single-line gantt) kept the buttons on top of
            // each other or clipped them off the top/bottom before
            // this guard. `BoxFit.contain` on the image inside keeps
            // the diagram vertically centred, so the extra height
            // reads as padding rather than distortion.
            if (displayHeight < _MermaidImage._minBoxHeight) {
              displayHeight = _MermaidImage._minBoxHeight;
              // Do NOT rescale displayWidth against the new height —
              // we deliberately keep the horizontal footprint so a
              // wide-aspect diagram does not grow vertically by
              // enlarging itself; the image inside shrinks via
              // BoxFit.contain and the extra vertical space becomes
              // negative space for the chrome.
            }
            return Center(
              child: SizedBox(
                width: displayWidth,
                height: displayHeight,
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Semantics(
                          label: context.l10n.mermaidDiagramLabel,
                          image: true,
                          child: InteractiveViewer(
                            transformationController: _transform,
                            minScale: 1.0,
                            maxScale: 5.0,
                            boundaryMargin: const EdgeInsets.all(
                              double.infinity,
                            ),
                            child: Image.memory(
                              widget.pngBytes,
                              fit: BoxFit.contain,
                              // The native snapshot arrives at the
                              // device-pixel-ratio scaled resolution;
                              // `filterQuality: medium` keeps the
                              // down-scale smooth without the jagged
                              // look of default nearest-neighbour.
                              filterQuality: FilterQuality.medium,
                              gaplessPlayback: true,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: AnimatedOpacity(
                          duration:
                              MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 150),
                          opacity: _isTransformed ? 1 : 0,
                          child: IgnorePointer(
                            ignoring: !_isTransformed,
                            child: _DiagramIconButton(
                              tooltip: l10n.mermaidReset,
                              icon: Icons.center_focus_strong_outlined,
                              onPressed: _resetTransform,
                            ),
                          ),
                        ),
                      ),
                      // Fullscreen affordance sits opposite the reset
                      // button so muscle memory keeps the two recovery
                      // gestures (recenter / expand) on the same
                      // horizontal rail. Always visible — dense
                      // flowchart / ER / mindmap diagrams are the
                      // reason this whole screen exists, so the user
                      // shouldn't have to transform the inline image
                      // first to discover the button.
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _DiagramIconButton(
                          tooltip: l10n.diagramFullscreenOpenTooltip,
                          icon: Icons.fullscreen,
                          onPressed: _openFullscreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Tonal round icon button floated over the inline mermaid diagram.
///
/// Used for both the recenter affordance (visible only while the
/// transform is dirty) and the fullscreen affordance (always
/// visible). 44 × 44 hit target for touch-target compliance even
/// though the painted icon is 20 dp.
class _DiagramIconButton extends StatelessWidget {
  const _DiagramIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        tooltip: tooltip,
        iconSize: 20,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        icon: Icon(icon, color: theme.colorScheme.onSurface),
        onPressed: onPressed,
      ),
    );
  }
}

class _MermaidPlaceholder extends StatelessWidget {
  const _MermaidPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = context.l10n.mermaidLoading;
    return Semantics(
      label: label,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(label, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _MermaidErrorPlaceholder extends StatelessWidget {
  const _MermaidErrorPlaceholder({this.detail});

  /// Renderer-supplied diagnostic (mermaid parse error, screenshot
  /// failure, JS exception message, …). Surfaced as a small
  /// monospace line beneath the localized body so we can actually
  /// see what went wrong on device — "diagram unreadable" with no
  /// context turned every iPhone iteration into guesswork.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = paletteForAdmonition(
      theme.colorScheme,
      AdmonitionKind.warning,
    );
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(palette.icon, size: 20, color: palette.accent),
              const SizedBox(width: 8),
              Text(
                l10n.mermaidRenderErrorTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: palette.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.mermaidRenderErrorBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.foreground,
            ),
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(
              detail!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.foreground.withValues(alpha: 0.75),
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: const [
                  'Menlo',
                  'Consolas',
                  'Roboto Mono',
                  'monospace',
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
