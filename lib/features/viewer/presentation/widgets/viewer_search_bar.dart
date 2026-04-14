import 'package:flutter/material.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';

/// Bottom search bar shown while the viewer's in-document search mode
/// is active.
///
/// Slides in from the bottom of the [Scaffold] body via [AnimatedSize].
/// Contains a [TextField], a live match counter, and previous / next
/// navigation buttons. The bar sits above the system navigation bar
/// via [SafeArea] so nothing is hidden behind the gesture handle on
/// notchless phones or the home indicator on iPhone.
///
/// [onQueryChanged] fires on every keystroke with no debounce — the
/// caller's match scan is a cheap in-memory string scan and running it
/// on every keystroke keeps the counter tight with typing rhythm.
///
/// [onSubmitted] advances to the next match when the keyboard's search /
/// done action is triggered, matching the behaviour users expect from
/// browser find-in-page bars.
class ViewerSearchBar extends StatelessWidget {
  const ViewerSearchBar({
    required this.controller,
    required this.focusNode,
    required this.matchCount,
    required this.currentMatchIndex,
    required this.onQueryChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// Total number of matches for the current query. Zero when the query
  /// is empty OR returned no matches — the widget differentiates the
  /// two states by checking [controller.text.isNotEmpty].
  final int matchCount;

  /// Zero-based index of the currently highlighted match, rendered as
  /// `current + 1 / total` to match the one-based convention browsers
  /// and editors use.
  final int currentMatchIndex;

  final ValueChanged<String> onQueryChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final scheme = theme.colorScheme;
    final hasQuery = controller.text.isNotEmpty;
    final hasMatches = matchCount > 0;

    return Material(
      color: scheme.surfaceContainer,
      // Top border acts as a visual separator from the document content
      // without needing a full elevation shadow that would obscure the
      // last line of text.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  // ── Close ─────────────────────────────────────────
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: l10n.viewerSearchCloseTooltip,
                    onPressed: onClose,
                  ),

                  // ── Search field ──────────────────────────────────
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: theme.textTheme.bodyLarge,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l10n.viewerSearchHint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: onQueryChanged,
                      onSubmitted: (_) {
                        if (hasMatches) onNext();
                      },
                    ),
                  ),

                  // ── Match counter ─────────────────────────────────
                  if (hasQuery)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        hasMatches
                            ? l10n.viewerSearchMatchCount(
                              currentMatchIndex + 1,
                              matchCount,
                            )
                            : l10n.viewerSearchNoResults,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              hasMatches
                                  ? scheme.onSurfaceVariant
                                  : scheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // ── Navigation ────────────────────────────────────
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up, size: 22),
                    tooltip: l10n.viewerSearchPreviousTooltip,
                    onPressed: hasMatches ? onPrevious : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 22),
                    tooltip: l10n.viewerSearchNextTooltip,
                    onPressed: hasMatches ? onNext : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
