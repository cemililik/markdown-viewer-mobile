import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/features/viewer/application/markdown_extensions/admonition.dart';
import 'package:markdown_viewer/features/viewer/application/mermaid_renderer_provider.dart';
import 'package:markdown_viewer/features/viewer/domain/services/mermaid_renderer.dart';
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
      _maybeRerender();
    }
  }

  void _maybeRerender() {
    final scheme = Theme.of(context).colorScheme;
    final directive =
        _sourceHasOwnDirective(widget.code)
            ? ''
            : buildMermaidInitDirective(scheme);

    if (_future != null && _renderedDirective == directive) {
      return;
    }
    _renderedDirective = directive;
    _future = ref
        .read(mermaidRendererProvider)
        .render(widget.code, initDirective: directive);
  }

  static bool _sourceHasOwnDirective(String source) {
    // Skip an optional leading YAML frontmatter block (--- ... ---) before
    // checking for a %%{init: directive, because mermaid source can legally
    // start with frontmatter followed by the init block.
    var scanFrom = 0;
    if (source.trimLeft().startsWith('---')) {
      final firstNl = source.indexOf('\n');
      if (firstNl > 0) {
        final opener = source.substring(0, firstNl).trimRight();
        if (opener == '---') {
          var cursor = firstNl + 1;
          while (cursor < source.length) {
            final nextNl = source.indexOf('\n', cursor);
            final lineEnd = nextNl < 0 ? source.length : nextNl;
            final line = source.substring(cursor, lineEnd).trimRight();
            if (line == '---' || line == '...') {
              scanFrom = nextNl < 0 ? source.length : nextNl + 1;
              break;
            }
            if (nextNl < 0) break;
            cursor = nextNl + 1;
          }
        }
      }
    }
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
    'attributeBackgroundColorOdd': surfaceContainer,
    'attributeBackgroundColorEven': surfaceContainerHigh,
    'relationColor': outline,
    'relationLabelColor': onSurface,
    'relationLabelBackground': surfaceContainer,

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
  final payload = jsonEncode({'theme': 'base', 'themeVariables': variables});
  return '%%{init: $payload}%%\n';
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columnWidth = constraints.maxWidth;
          var displayWidth = columnWidth;
          var displayHeight = displayWidth / aspectRatio;
          if (displayHeight > maxDiagramHeight) {
            displayHeight = maxDiagramHeight;
            displayWidth = displayHeight * aspectRatio;
          }
          return Center(
            child: SizedBox(
              width: displayWidth,
              height: displayHeight,
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: InteractiveViewer(
                        transformationController: _transform,
                        minScale: 1.0,
                        maxScale: 5.0,
                        boundaryMargin: const EdgeInsets.all(double.infinity),
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
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _isTransformed ? 1 : 0,
                        child: IgnorePointer(
                          ignoring: !_isTransformed,
                          child: _CenterButton(
                            tooltip: l10n.mermaidReset,
                            onPressed: _resetTransform,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({required this.tooltip, required this.onPressed});

  final String tooltip;
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
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(
          Icons.center_focus_strong_outlined,
          color: theme.colorScheme.onSurface,
        ),
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
