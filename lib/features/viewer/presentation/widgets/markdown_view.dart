import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart' as hl_dark;
import 'package:flutter_highlight/themes/atom-one-light.dart' as hl_light;
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
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
/// What this widget customises on top of the package defaults:
///
/// - Picks the right top-level [MarkdownConfig] (`defaultConfig` or
///   `darkConfig`) based on the active [ThemeData.brightness] so light
///   and dark theme switching works without rebuilding subtrees.
/// - Replaces [PreConfig] with a Material-3-aware variant: code blocks
///   sit on `colorScheme.surfaceContainer*` instead of the package's
///   hard-coded greys, and the syntax theme is the well-known
///   `atom-one-light` / `atom-one-dark` from `flutter_highlight`.
///
/// Custom block builders for mermaid, math, and admonitions land in
/// later phases by plugging into the same [MarkdownConfig] via
/// additional config slots.
class MarkdownView extends StatelessWidget {
  const MarkdownView({required this.document, super.key});

  final Document document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base =
        isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
    final config = base.copy(configs: [_buildPreConfig(theme, isDark: isDark)]);

    return MarkdownWidget(
      data: document.source,
      config: config,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  PreConfig _buildPreConfig(ThemeData theme, {required bool isDark}) {
    final scheme = theme.colorScheme;
    return PreConfig(
      decoration: BoxDecoration(
        color:
            isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      textStyle: TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const [
          'JetBrainsMono',
          'Menlo',
          'Consolas',
          'Roboto Mono',
        ],
        fontSize: 14,
        height: 1.45,
        color: scheme.onSurface,
      ),
      styleNotMatched: TextStyle(color: scheme.onSurface),
      theme: isDark ? hl_dark.atomOneDarkTheme : hl_light.atomOneLightTheme,
    );
  }
}
