import 'package:flutter/material.dart';

/// Single entry in the [LibrarySpeedDial] menu. Owns its own
/// label, icon, and tap callback so the dial renders as a list
/// of these without having to special-case each item.
class LibrarySpeedDialAction {
  const LibrarySpeedDialAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;

  /// Tap handler. Pass `null` to render the entry as visually
  /// disabled (used for "Sync repository", which is gated on the
  /// Phase 4.5 implementation).
  final VoidCallback? onTap;
}

/// Speed dial floating action button shown on the populated state
/// of the library home screen.
///
/// Layout: a column of [LibrarySpeedDialAction] mini-FABs above a
/// primary FAB. The primary FAB toggles between a "+" icon (menu
/// closed) and a "×" icon (menu open). When the menu is closed
/// the mini-FABs are collapsed to scale 0 and removed from
/// hit-testing via `IgnorePointer`. When it opens, each mini-FAB
/// fades and scales in with a staggered delay so the eye reads
/// them top-to-bottom rather than as a single popping cluster.
///
/// A tap outside the dial — anywhere on the underlying scaffold
/// — closes the menu through a transparent full-bleed
/// `ModalBarrier` rendered underneath the column. The barrier
/// only exists while the menu is open, so taps on the rest of
/// the screen pass through normally in the closed state.
///
/// The widget owns its own open/closed state. Callers do not need
/// to thread a controller through their build because the menu
/// has no behavioural reason to live longer than a single
/// tap-expand-pick interaction.
class LibrarySpeedDial extends StatefulWidget {
  const LibrarySpeedDial({
    required this.actions,
    required this.openTooltip,
    required this.closeTooltip,
    super.key,
  });

  /// Menu entries shown when the dial is open. Rendered top to
  /// bottom in the order supplied so the caller controls the
  /// reading order.
  final List<LibrarySpeedDialAction> actions;

  /// Tooltip shown on the primary FAB while the menu is closed.
  final String openTooltip;

  /// Tooltip shown on the primary FAB while the menu is open.
  final String closeTooltip;

  @override
  State<LibrarySpeedDial> createState() => _LibrarySpeedDialState();
}

class _LibrarySpeedDialState extends State<LibrarySpeedDial>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
  }

  void _close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
  }

  void _runAction(VoidCallback? action) {
    if (action == null) return;
    _close();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        // Transparent full-bleed barrier behind the menu — soaks
        // up taps anywhere on the screen so a stray tap closes
        // the dial without dispatching to whatever was under it.
        // Only mounted while the menu is open so the closed-state
        // FAB does not steal hit-tests for the rest of the body.
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < widget.actions.length; i += 1)
              _SpeedDialItem(
                action: widget.actions[i],
                isOpen: _isOpen,
                index: i,
                total: widget.actions.length,
                onTap: () => _runAction(widget.actions[i].onTap),
              ),
            const SizedBox(height: 12),
            FloatingActionButton(
              tooltip: _isOpen ? widget.closeTooltip : widget.openTooltip,
              onPressed: _toggle,
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                turns: _isOpen ? 0.125 : 0,
                child: Icon(
                  Icons.add,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Individual mini-FAB row inside the speed dial. Renders the
/// label as a small Material 3 surface chip on the left and the
/// circular mini-FAB on the right, both scaling/fading in with a
/// staggered delay so the eye reads the menu top-to-bottom.
class _SpeedDialItem extends StatelessWidget {
  const _SpeedDialItem({
    required this.action,
    required this.isOpen,
    required this.index,
    required this.total,
    required this.onTap,
  });

  final LibrarySpeedDialAction action;
  final bool isOpen;
  final int index;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEnabled = action.onTap != null;

    // Stagger so the topmost item (index 0) animates in last
    // when opening and out first when closing. Reading from top
    // to bottom is more natural than the reverse.
    final reverseIndex = total - 1 - index;
    final delayMs = reverseIndex * 30;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AnimatedSlide(
        offset: isOpen ? Offset.zero : const Offset(0, 0.4),
        duration: Duration(milliseconds: 220 + delayMs),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: isOpen ? 1 : 0,
          duration: Duration(milliseconds: 180 + delayMs),
          curve: Curves.easeOutCubic,
          child: IgnorePointer(
            ignoring: !isOpen,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      action.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color:
                            isEnabled
                                ? scheme.onSurface
                                : scheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.small(
                  heroTag: 'libspeed-${action.label}',
                  tooltip: action.label,
                  backgroundColor:
                      isEnabled
                          ? scheme.secondaryContainer
                          : scheme.surfaceContainerHigh,
                  foregroundColor:
                      isEnabled
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface.withValues(alpha: 0.4),
                  elevation: isEnabled ? 4 : 0,
                  onPressed: isEnabled ? onTap : null,
                  child: Icon(action.icon),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
