import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/features/viewer/application/markdown_extensions/admonition.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:markdown_widget/markdown_widget.dart';

/// CSS class token that `package:markdown`'s [md.AlertBlockSyntax]
/// stamps on the generated title paragraph it prepends inside every
/// alert `<div>`. Used by the span-node guard below to recognise
/// the synthetic title without having to track child indices.
const String _alertTitleClass = 'markdown-alert-title';

/// Renders a GitHub-style admonition (alert) as a themed container.
///
/// The widget is purely presentational — it takes an
/// [AdmonitionKind] and an already-built body [InlineSpan] and
/// decides on its own what icon, colour, and localized title to
/// use. The classification of "is this a markdown-alert div?"
/// happens one level up in [AdmonitionSpanNode] via
/// [tryParseAdmonitionKind].
///
/// The visual language:
///
/// - A rounded 8 px container with a thin [ColorScheme.outlineVariant]
///   border and a kind-specific tinted background (Material 3
///   `*Container` roles).
/// - Header row: kind icon + localized title in the matching
///   accent foreground colour.
/// - Body: the accumulated inline children rendered via [Text.rich]
///   on a transparent background, inheriting the body text style so
///   nested emphasis / links / code still work.
class AdmonitionView extends StatelessWidget {
  const AdmonitionView({required this.kind, required this.body, super.key});

  final AdmonitionKind kind;

  /// Pre-built content of the admonition body. Everything the user
  /// wrote after the `> [!KIND]` marker, already parsed into inline
  /// spans by markdown_widget's visitor.
  final InlineSpan body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = paletteForAdmonition(theme.colorScheme, kind);
    final l10n = context.l10n;
    final title = titleForAdmonition(l10n, kind);

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
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: palette.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Inherit body text colour for the nested content so
          // regular prose reads on the tinted background. The
          // nested spans were built with the default markdown body
          // style — this DefaultTextStyle wraps them without
          // rebuilding.
          DefaultTextStyle(
            style:
                theme.textTheme.bodyMedium?.copyWith(
                  color: palette.foreground,
                ) ??
                TextStyle(color: palette.foreground),
            child: Text.rich(body),
          ),
        ],
      ),
    );
  }
}

/// Pure helper that returns the localized title for [kind]. Kept as
/// a top-level function (rather than an instance method on
/// [AdmonitionView]) because it has no widget state and is trivially
/// unit-testable in isolation.
@visibleForTesting
String titleForAdmonition(AppLocalizations l10n, AdmonitionKind kind) {
  return switch (kind) {
    AdmonitionKind.note => l10n.admonitionNoteTitle,
    AdmonitionKind.tip => l10n.admonitionTipTitle,
    AdmonitionKind.important => l10n.admonitionImportantTitle,
    AdmonitionKind.warning => l10n.admonitionWarningTitle,
    AdmonitionKind.caution => l10n.admonitionCautionTitle,
  };
}

/// Pure helper that returns the icon / accent / background /
/// foreground tuple for [kind] resolved against [scheme]. Kept as a
/// top-level function for the same reasons as [titleForAdmonition].
@visibleForTesting
AdmonitionPalette paletteForAdmonition(
  ColorScheme scheme,
  AdmonitionKind kind,
) {
  return switch (kind) {
    AdmonitionKind.note => AdmonitionPalette(
      icon: Icons.info_outline,
      accent: scheme.primary,
      background: scheme.primaryContainer.withValues(alpha: 0.35),
      foreground: scheme.onSurface,
    ),
    AdmonitionKind.tip => AdmonitionPalette(
      icon: Icons.lightbulb_outline,
      accent: scheme.tertiary,
      background: scheme.tertiaryContainer.withValues(alpha: 0.35),
      foreground: scheme.onSurface,
    ),
    AdmonitionKind.important => AdmonitionPalette(
      icon: Icons.star_outline,
      accent: scheme.secondary,
      background: scheme.secondaryContainer.withValues(alpha: 0.35),
      foreground: scheme.onSurface,
    ),
    AdmonitionKind.warning => AdmonitionPalette(
      icon: Icons.warning_amber_outlined,
      accent: scheme.error,
      background: scheme.errorContainer.withValues(alpha: 0.35),
      foreground: scheme.onSurface,
    ),
    AdmonitionKind.caution => AdmonitionPalette(
      icon: Icons.dangerous_outlined,
      accent: scheme.error,
      background: scheme.errorContainer.withValues(alpha: 0.5),
      foreground: scheme.onSurface,
    ),
  };
}

/// Visual tuple consumed by [AdmonitionView]. Public so the pure
/// helper [paletteForAdmonition] can return it directly.
@immutable
class AdmonitionPalette {
  const AdmonitionPalette({
    required this.icon,
    required this.accent,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color accent;
  final Color background;
  final Color foreground;
}

/// `SpanNode` that turns a `markdown-alert` `<div>` element emitted
/// by `AlertBlockSyntax` into a [WidgetSpan] hosting an
/// [AdmonitionView].
///
/// `AlertBlockSyntax` prepends a generated title paragraph
/// (`<p class="markdown-alert-title">Note</p>` or similar) to the
/// div's children. We do not want to render that paragraph because
/// the [AdmonitionView] draws its own localized title with an icon.
///
/// The previous revision of this class dropped the **first** child
/// it received, period. That works today, but it would silently eat
/// real user content if `AlertBlockSyntax` ever stopped emitting
/// the synthetic title — the entire admonition body's first block
/// would just disappear. This revision instead checks the original
/// element's children at construction time and tells the span node
/// whether to drop the first incoming child via [_dropFirstChild],
/// so the drop is conditional on actually finding the title
/// paragraph.
class AdmonitionSpanNode extends ElementNode {
  AdmonitionSpanNode({required this.kind, required bool dropFirstChild})
    : _dropFirstChild = dropFirstChild;

  final AdmonitionKind kind;
  final bool _dropFirstChild;
  bool _firstChildSkipped = false;

  @override
  void accept(SpanNode? node) {
    if (_dropFirstChild && !_firstChildSkipped) {
      _firstChildSkipped = true;
      // Intentionally skip — the generated title paragraph would
      // otherwise duplicate AdmonitionView's own header.
      return;
    }
    super.accept(node);
  }

  @override
  InlineSpan build() {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: AdmonitionView(kind: kind, body: childrenSpan),
    );
  }
}

/// Returns `true` when [element]'s first child is the synthetic
/// title paragraph that `AlertBlockSyntax` prepends to every alert
/// div. Inspecting the element directly (rather than indirectly
/// counting the first accepted SpanNode) makes
/// [AdmonitionSpanNode]'s drop behaviour resilient to a future
/// `AlertBlockSyntax` revision that stops generating the title.
bool _firstChildIsAlertTitle(md.Element element) {
  final children = element.children;
  if (children == null || children.isEmpty) {
    return false;
  }
  final first = children.first;
  if (first is! md.Element || first.tag != 'p') {
    return false;
  }
  final classAttr = first.attributes['class'] ?? '';
  return classAttr.split(RegExp(r'\s+')).contains(_alertTitleClass);
}

/// Builds the `SpanNodeGeneratorWithTag` entries the viewer's
/// `MarkdownGenerator` needs to map alert `<div>` elements into
/// [AdmonitionSpanNode]s.
///
/// Any `<div>` whose class does NOT identify it as a markdown alert
/// falls back to a transparent [ConcreteElementNode] so its children
/// still render as normal block content — this guards against raw
/// HTML blocks slipping through with a random class attribute.
List<SpanNodeGeneratorWithTag> buildAdmonitionSpanNodeGenerators() {
  return [
    SpanNodeGeneratorWithTag(
      tag: admonitionElementTag,
      generator: (element, config, visitor) {
        final kind = tryParseAdmonitionKind(element);
        if (kind == null) {
          return ConcreteElementNode();
        }
        return AdmonitionSpanNode(
          kind: kind,
          dropFirstChild: _firstChildIsAlertTitle(element),
        );
      },
    ),
  ];
}
