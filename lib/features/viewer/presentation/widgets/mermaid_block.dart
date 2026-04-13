import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/features/viewer/application/markdown_extensions/admonition.dart';
import 'package:markdown_viewer/features/viewer/application/mermaid_renderer_provider.dart';
import 'package:markdown_viewer/features/viewer/domain/services/mermaid_renderer.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/admonition_view.dart';

/// Renders a single mermaid fenced code block as an inline SVG.
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
/// the SVG arrives.
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
    final brightness = Theme.of(context).brightness;
    final directive =
        _sourceHasOwnDirective(widget.code)
            ? ''
            : buildMermaidInitDirective(scheme, brightness);

    if (_future != null && _renderedDirective == directive) {
      return;
    }
    _renderedDirective = directive;
    _future = ref
        .read(mermaidRendererProvider)
        .render(widget.code, initDirective: directive);
  }

  static bool _sourceHasOwnDirective(String source) {
    return source.trimLeft().startsWith('%%{init:');
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
          return _MermaidSvg(svg: result.svg);
        }
        return const _MermaidErrorPlaceholder();
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
/// [brightness] is currently only used to decide a few contrast
/// fallbacks (task text colour in gantt charts that have to read
/// on top of a filled bar); the rest of the palette comes from
/// [scheme] directly so it follows both dynamic-colour seed changes
/// and light ⇄ dark flips.
String buildMermaidInitDirective(ColorScheme scheme, Brightness brightness) {
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
  };

  // Mermaid accepts JSON syntax inside the init directive, so we
  // can let `jsonEncode` do all the escaping work and avoid hand-
  // rolled string concatenation edge cases.
  final payload = jsonEncode({'theme': 'base', 'themeVariables': variables});
  return '%%{init: $payload}%%\n';
}

/// Pan+zoom container for a mermaid SVG with a smooth reset-to-centre
/// affordance.
///
/// The SVG carries its natural size in a `viewBox="minX minY W H"`
/// attribute. We parse it once, compute `aspectRatio = W / H`, and
/// hand that to an [AspectRatio] parent so the widget takes the
/// column width and scales its height to match — the diagram keeps
/// its intrinsic proportions instead of collapsing to zero height
/// inside the enclosing `ListView`.
///
/// The SVG itself lives inside an [InteractiveViewer] so the user
/// can pinch-zoom and two-finger-pan to inspect small labels on
/// wide diagrams. `boundaryMargin: infinity` lets the user pan
/// anywhere while zoomed; `ClipRect` makes sure the zoomed-in
/// content does not bleed into adjacent markdown blocks.
///
/// A small tonal icon button in the top-left fades in whenever the
/// underlying `TransformationController` has moved off the identity
/// matrix. Tapping it runs a short [Matrix4Tween] animation back
/// to identity, so a user who has zoomed in and panned out of
/// frame can recover in one tap with a smooth transition rather
/// than a jarring snap.
class _MermaidSvg extends StatefulWidget {
  const _MermaidSvg({required this.svg});

  final String svg;

  /// Matches the four numbers inside a `viewBox="..."` attribute,
  /// tolerating decimal, negative, and exponent syntax. Captures
  /// the width (group 1) and height (group 2).
  static final RegExp _viewBox = RegExp(
    r'viewBox\s*=\s*"\s*[\d.eE+-]+\s+[\d.eE+-]+\s+([\d.eE+-]+)\s+([\d.eE+-]+)"',
  );

  static double parseAspectRatio(String svg) {
    final match = _viewBox.firstMatch(svg);
    if (match == null) {
      return 16 / 9;
    }
    final w = double.tryParse(match.group(1)!);
    final h = double.tryParse(match.group(2)!);
    if (w == null || h == null || w <= 0 || h <= 0) {
      return 16 / 9;
    }
    return w / h;
  }

  @override
  State<_MermaidSvg> createState() => _MermaidSvgState();
}

class _MermaidSvgState extends State<_MermaidSvg>
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

  void _onTransformChanged() {
    final transformed = !_transform.value.isIdentity();
    if (transformed != _isTransformed) {
      setState(() => _isTransformed = transformed);
    }
  }

  void _resetTransform() {
    // Build a fresh Matrix4Tween every time so the animation is
    // always based on the current matrix — without this a quick
    // zoom immediately after a reset would interpolate from the
    // stale starting matrix.
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
    final aspectRatio = _MermaidSvg.parseAspectRatio(widget.svg);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transform,
                  minScale: 1.0,
                  maxScale: 5.0,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  child: SvgPicture.string(widget.svg, fit: BoxFit.contain),
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
  const _MermaidErrorPlaceholder();

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
        ],
      ),
    );
  }
}
