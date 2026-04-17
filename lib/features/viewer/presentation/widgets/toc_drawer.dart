import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';

/// Right-side drawer listing the headings of the active
/// document. Tapping a heading closes the drawer and invokes
/// [onHeadingSelected] so the viewer can animate the scroll
/// into place — the drawer itself deliberately does not hold a
/// `ScrollController` reference so that the jump logic stays
/// the viewer's concern and the drawer stays a pure
/// render-and-dispatch widget.
///
/// The list uses progressive indent based on heading level: an
/// H1 gets no indent, every deeper level adds roughly 12 dp.
/// This gives the eye a cheap outline map of the document
/// structure without needing expansion tiles — most markdown
/// documents are shallow enough that every heading fits in
/// view, and a flat scroll is faster to scan than an
/// interactive tree.
class TocDrawer extends StatelessWidget {
  const TocDrawer({
    required this.document,
    required this.onHeadingSelected,
    super.key,
  });

  final Document document;

  /// Invoked with the tapped [HeadingRef] AFTER the drawer has
  /// been popped. The caller is expected to resolve the
  /// matching widget key and drive
  /// `Scrollable.ensureVisible` — see `ViewerScreen._scrollToHeading`.
  final ValueChanged<HeadingRef> onHeadingSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final headings = document.headings;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.format_list_bulleted,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.viewerTocTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child:
                  headings.isEmpty
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 24,
                          ),
                          child: Text(
                            l10n.viewerTocEmpty,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: headings.length,
                        itemBuilder: (context, index) {
                          final heading = headings[index];
                          return _TocEntry(
                            heading: heading,
                            onTap: () async {
                              HapticFeedback.selectionClick().ignore();
                              // Fire-and-forget the pop — the close
                              // animation itself is what we want to
                              // wait out, not the Navigator's
                              // internal `Future<bool>` return value.
                              unawaited(Navigator.of(context).maybePop());
                              // Wait for Flutter's default drawer-close
                              // transition (≈ 246 ms measured on iOS 18
                              // and Android 14) to finish before firing
                              // the scroll. Without this hop the
                              // post-frame `Scrollable.ensureVisible`
                              // fights with the NestedScrollView
                              // viewport re-measurement that the drawer
                              // dismissal triggers — the observed
                              // symptom on v1.0 was the first tap
                              // snapping the document back to offset 0
                              // and the second tap (drawer already
                              // closed) working correctly.
                              await Future<void>.delayed(
                                const Duration(milliseconds: 300),
                              );
                              onHeadingSelected(heading);
                            },
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TocEntry extends StatelessWidget {
  const _TocEntry({required this.heading, required this.onTap});

  final HeadingRef heading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // H1 → 0 extra, H2 → 12 dp, H3 → 24 dp, …
    // The clamp guards against pathological H7+ cases even
    // though the parser rejects anything outside [1, 6].
    final indent = ((heading.level - 1).clamp(0, 5)) * 12.0;
    final textStyle =
        heading.level == 1
            ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)
            : heading.level == 2
            ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)
            : theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            );

    return Semantics(
      button: true,
      label: heading.text,
      hint: context.l10n.viewerTocNavigateHint,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20 + indent, 10, 20, 10),
          child: ExcludeSemantics(
            child: Text(
              heading.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ),
      ),
    );
  }
}
