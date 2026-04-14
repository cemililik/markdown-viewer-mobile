import 'package:flutter/material.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';

/// A compact search field + match counter + next/prev
/// chevrons, sized to sit inside a `Scaffold.appBar`'s `title`
/// slot when the viewer's search mode is active.
///
/// Owns the `TextField` focus + controller. Emits:
///
/// - [onQueryChanged] on every keystroke (no debounce — the
///   viewer's match computation is a cheap in-memory string
///   scan and running it on every keystroke keeps the counter
///   tight).
/// - [onPrevious] / [onNext] when the chevrons are tapped.
/// - [onClose] when the leading close button is tapped or the
///   user presses ESC (reserved for future hardware keyboard
///   support; touch users rely on the close button).
///
/// The widget deliberately does not expose "enter = next"
/// logic via `onSubmitted` — mobile keyboards do not reliably
/// surface a "search" key, and forcing a keyboard dismissal on
/// every jump is more disruption than it is worth. Users jump
/// via the chevron affordance.
class InDocSearchBar extends StatelessWidget {
  const InDocSearchBar({
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

  /// Total number of matches across the document for the
  /// current query. Zero when the query is empty OR when the
  /// query returned no matches — the widget differentiates via
  /// the separate `controller.text.isEmpty` check so an empty
  /// query renders a bare search field and a non-empty query
  /// with no matches renders the localized "No matches" hint.
  final int matchCount;

  /// Zero-based index of the current match inside the match
  /// list. Rendered as `current + 1 / total` so the user sees a
  /// one-based counter familiar from browsers and editors.
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

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.viewerSearchCloseTooltip,
          onPressed: onClose,
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            style: theme.textTheme.titleMedium,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.viewerSearchHint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: onQueryChanged,
          ),
        ),
        if (hasQuery)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              matchCount == 0
                  ? l10n.viewerSearchNoResults
                  : l10n.viewerSearchMatchCount(
                    currentMatchIndex + 1,
                    matchCount,
                  ),
              style: theme.textTheme.labelSmall?.copyWith(
                color: matchCount == 0 ? scheme.error : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up),
          tooltip: l10n.viewerSearchPreviousTooltip,
          onPressed: matchCount == 0 ? null : onPrevious,
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          tooltip: l10n.viewerSearchNextTooltip,
          onPressed: matchCount == 0 ? null : onNext,
        ),
      ],
    );
  }
}
