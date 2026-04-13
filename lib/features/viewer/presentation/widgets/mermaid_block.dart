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
/// Hooked into [MarkdownView] via `PreConfig.builder`. The widget
/// owns no parsing logic — it just calls the application-layer
/// [mermaidRendererProvider] with the block's body, then displays
/// either the returned SVG or a localized error placeholder. Pending
/// state shows a low-key spinner sized to roughly the eventual
/// diagram footprint so the surrounding text does not jump when the
/// SVG arrives.
///
/// The error placeholder reuses [paletteForAdmonition] with
/// [AdmonitionKind.warning] so a failed mermaid diagram has the same
/// visual language as a `> [!WARNING]` admonition. This keeps the
/// reading column free of new accent colours while still flagging
/// the failure clearly.
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ref.read inside didChangeDependencies (rather than initState)
    // because the renderer is sourced from an InheritedWidget that
    // is not yet available during initState in some test harnesses.
    _future ??= ref.read(mermaidRendererProvider).render(widget.code);
  }

  @override
  void didUpdateWidget(covariant MermaidBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _future = ref.read(mermaidRendererProvider).render(widget.code);
    }
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

class _MermaidSvg extends StatelessWidget {
  const _MermaidSvg({required this.svg});

  final String svg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SvgPicture.string(svg, fit: BoxFit.contain),
        ),
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
