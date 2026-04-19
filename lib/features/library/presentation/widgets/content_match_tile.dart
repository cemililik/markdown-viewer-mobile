import 'package:flutter/material.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/features/library/domain/services/library_content_search.dart';

/// Reusable list tile that renders a single [ContentSearchMatch].
///
/// Used by both the cross-library content search results on the
/// Recents tab and the source-scoped content search results on the
/// folder / synced-repo tabs. Kept deliberately dumb — navigation
/// lives in the caller via [onTap] because different surfaces route
/// differently (Recents pushes the viewer directly with an already-
/// materialised path; a folder source has to go through
/// `openFolderEntry` so the platform materializer can claim the
/// security-scoped bookmark before the viewer reads bytes).
class ContentMatchTile extends StatelessWidget {
  const ContentMatchTile({
    required this.match,
    required this.onTap,
    this.showSourceLabel = true,
    super.key,
  });

  /// The content-search hit rendered by this tile. Pre-computed
  /// offsets inside [ContentSearchMatch.snippet] drive the in-place
  /// highlight.
  final ContentSearchMatch match;

  /// Fired when the user taps the tile. The caller owns navigation
  /// (the folder body materialises through its bookmark; the library
  /// screen pushes the viewer directly), so this tile stays ignorant
  /// of which code path activates.
  final VoidCallback onTap;

  /// Whether to paint the "Recent / Folder: … / Repo: …" badge under
  /// the snippet. Redundant when every match on the surface already
  /// belongs to the same source (e.g. a folder body showing only
  /// matches from that folder) — hiding the badge there tightens the
  /// vertical rhythm without losing information.
  final bool showSourceLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

    return ListTile(
      leading: Icon(Icons.description_outlined, color: scheme.onSurfaceVariant),
      title: Text(
        match.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 2),
          _HighlightedSnippet(match: match),
          if (showSourceLabel || match.matchCount > 1) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (showSourceLabel)
                  Flexible(
                    child: Text(
                      match.sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (match.matchCount > 1) ...[
                  if (showSourceLabel) const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Text(
                      l10n.libraryContentSearchMoreMatches(match.matchCount),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Renders [match.snippet] with the matched fragment painted on a
/// primary-container pill — visually consistent with the
/// search-inside-document highlighter in the viewer.
class _HighlightedSnippet extends StatelessWidget {
  const _HighlightedSnippet({required this.match});

  final ContentSearchMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snippet = match.snippet;
    final start = match.snippetMatchStart;
    final length = match.snippetMatchLength;
    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.4,
    );

    // Guard against edge cases where the computed match offsets do
    // not map cleanly back into the snippet (pathological Unicode
    // collapse, very short snippets). Fall back to a plain label so
    // the tile never renders with a RangeError.
    final canHighlight =
        length > 0 && start >= 0 && start + length <= snippet.length;

    if (!canHighlight) {
      return Text(
        snippet,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    final before = snippet.substring(0, start);
    final highlight = snippet.substring(start, start + length);
    final after = snippet.substring(start + length);

    // `Text.rich` respects the ambient `MediaQuery.textScaler`
    // (user font-size preference, Dynamic Type on iOS, system
    // font-scale on Android), which the raw `RichText` primitive
    // does not. A user who bumps the OS text size to 150% would
    // otherwise see every other label grow while the search
    // snippet stayed at its design pixel size.
    // Reference: PR-review NEW-009.
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: before),
          TextSpan(
            text: highlight,
            style: baseStyle?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
              backgroundColor: scheme.primaryContainer,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
