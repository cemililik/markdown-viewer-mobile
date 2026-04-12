import 'package:flutter/material.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_widget/markdown_widget.dart';

/// Renders a parsed [Document] using `markdown_widget`.
///
/// Phase 1.2 intentionally keeps the rendering surface minimal: plain
/// CommonMark + GFM via the package defaults, no custom block builders
/// yet. Mermaid, math, admonitions, and syntax-highlighted code are
/// added in later phases by plugging block builders into the
/// [MarkdownGenerator] passed to [MarkdownWidget].
///
/// The config is chosen based on the active [ThemeData.brightness] so
/// light / dark theme switching works without a rebuild of this class.
class MarkdownView extends StatelessWidget {
  const MarkdownView({required this.document, super.key});

  final Document document;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config =
        isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;

    return MarkdownWidget(
      data: document.source,
      config: config,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
