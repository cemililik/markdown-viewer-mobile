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
/// owns no parsing logic — it just calls the application-layer
/// [mermaidRendererProvider] with the block's body, then displays
/// either the returned SVG or a localized error placeholder.
///
/// The renderer is called with a [MermaidDiagramTheme] derived from
/// the active Flutter brightness, so the resulting SVG has the
/// right palette for both light and dark mode. Flipping the app
/// theme rebuilds the widget, triggers a fresh render, and the
/// renderer's cache keeps the previously-rendered opposite-theme
/// SVG in its LRU slot — toggling back is instant.
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
  Brightness? _renderedBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_future == null || _renderedBrightness != brightness) {
      _renderedBrightness = brightness;
      _future = ref
          .read(mermaidRendererProvider)
          .render(widget.code, theme: _themeFor(brightness));
    }
  }

  @override
  void didUpdateWidget(covariant MermaidBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      final brightness = Theme.of(context).brightness;
      _renderedBrightness = brightness;
      _future = ref
          .read(mermaidRendererProvider)
          .render(widget.code, theme: _themeFor(brightness));
    }
  }

  static MermaidDiagramTheme _themeFor(Brightness brightness) {
    return switch (brightness) {
      Brightness.dark => MermaidDiagramTheme.dark,
      Brightness.light => MermaidDiagramTheme.defaultTheme,
    };
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

/// Pan+zoom container for a mermaid SVG.
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
class _MermaidSvg extends StatelessWidget {
  const _MermaidSvg({required this.svg});

  final String svg;

  /// Matches the four numbers inside a `viewBox="..."` attribute,
  /// tolerating decimal, negative, and exponent syntax. Captures
  /// the width (group 1) and height (group 2).
  static final RegExp _viewBox = RegExp(
    r'viewBox\s*=\s*"\s*[\d.eE+-]+\s+[\d.eE+-]+\s+([\d.eE+-]+)\s+([\d.eE+-]+)"',
  );

  @override
  Widget build(BuildContext context) {
    final aspectRatio = _parseAspectRatio(svg);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRect(
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            // Infinite boundary so the user can pan the zoomed
            // content anywhere within the clip, without fighting
            // the default bounded behaviour that snaps back to
            // the edge.
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: SvgPicture.string(svg, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  static double _parseAspectRatio(String svg) {
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
