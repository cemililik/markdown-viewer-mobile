import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/features/library/application/content_search_provider.dart';
import 'package:markdown_viewer/features/library/presentation/widgets/content_match_tile.dart';

/// Sliver that renders the cross-library full-text search results
/// used on the Recents tab.
///
/// Hidden by default — only mounts once the user has typed at least
/// [_minQueryLength] characters. Listens to
/// [contentSearchControllerProvider] so the list stays in sync with
/// the debounced scan. Each tile tap routes straight to the viewer
/// at the matching path (recents entries are already stored with a
/// viewer-readable path, so no materializer detour is needed here —
/// folder / synced-repo tabs have their own in-body search which
/// takes care of the bookmark claim).
class ContentSearchResultsSliver extends ConsumerWidget {
  const ContentSearchResultsSliver({super.key});

  /// Content search is only useful when the user has committed to
  /// a query. Below three characters the scan produces too many
  /// false positives ("the", "of", "to") and wastes isolate time
  /// for no practical benefit.
  static const int _minQueryLength = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(contentSearchControllerProvider);

    if (state.query.length < _minQueryLength) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (state.isLoading && state.results.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.libraryContentSearchLoading,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (state.results.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            l10n.libraryContentSearchEmpty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Results + header rendered through a single `SliverList.builder`
    // so each `ContentMatchTile` materialises lazily as the user
    // scrolls. The previous eager `SliverList.list(children: [...])`
    // instantiated every tile on every state tick, which added a
    // frame-time cost proportional to the (capped) 50-result list —
    // measurable on mid-tier Android during search rebuilds.
    // Reference: performance-review PR-20260419-011.
    final matches = state.results;
    return SliverList.builder(
      itemCount: matches.length + 1, // +1 for the header row
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.manage_search_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.libraryContentSearchHeader,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }
        final match = matches[index - 1];
        return ContentMatchTile(
          match: match,
          onTap: () {
            context.push(ViewerRoute.location(match.documentId.value));
          },
        );
      },
    );
  }
}
