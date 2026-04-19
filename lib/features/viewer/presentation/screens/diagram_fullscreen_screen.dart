import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';

/// Arguments handed to [DiagramFullscreenScreen] via
/// `GoRouter.push(extra: …)`.
///
/// The raster bytes produced by the Mermaid renderer are captured at
/// device-pixel-ratio resolution, so reusing them on the fullscreen
/// screen gives a crisp image without re-running the WebView.
/// Natural width / height come from the WebView's CSS-pixel layout
/// measurements and are used here only to set an aspect ratio on the
/// initial composition — the fullscreen [InteractiveViewer]
/// immediately lets the user pan and zoom beyond those bounds.
class DiagramFullscreenArgs {
  /// Constructs the payload. [pngBytes] is the already-rendered
  /// diagram image; the caller must not mutate the underlying buffer
  /// after passing it in.
  const DiagramFullscreenArgs({
    required this.pngBytes,
    required this.width,
    required this.height,
  });

  /// Raw PNG bytes of the diagram image, produced upstream by
  /// [MermaidRenderer.render] at device-pixel-ratio resolution.
  /// Rendered via `Image.memory` on the fullscreen route.
  final Uint8List pngBytes;

  /// Natural width in CSS pixels, read from the rendering WebView's
  /// post-layout measurement. Used only to seed an aspect ratio on
  /// the initial composition — the fullscreen `InteractiveViewer`
  /// lets the reader zoom well beyond it.
  final double width;

  /// Natural height in CSS pixels, captured alongside [width] from
  /// the same WebView measurement pass. Same aspect-ratio role as
  /// [width].
  final double height;
}

/// Dedicated fullscreen route for an already-rendered Mermaid diagram.
///
/// Entry path from the inline viewer:
///
/// 1. The reader taps the expand-icon affordance inside `_MermaidImage`.
/// 2. `MermaidBlock` pushes [DiagramRoute] on the current [GoRouter]
///    stack with a [DiagramFullscreenArgs] payload.
/// 3. This screen mounts, takes over the edge-to-edge viewport, and
///    drives its own `TransformationController` — the inline diagram
///    keeps its own transform so popping back restores the exact
///    pan/zoom state the reader left.
///
/// The design brief from the maintainer was explicit: the fullscreen
/// view must not break the reading flow. Concretely that means:
///
/// - Popping back goes to the exact scroll offset the document was
///   at (automatic, because we `push` rather than `go`).
/// - The "Reset view" button is the same affordance the inline
///   diagram exposes, so muscle memory carries over.
/// - The top chrome bar (close + reset) is **always visible**. An
///   earlier iteration toggled it on tap, which trapped users who
///   missed the close button by a few pixels — the stray tap hid
///   the button they were trying to hit and, on iOS with the status
///   bar suppressed by [SystemUiMode.immersiveSticky], left no
///   system-level back affordance as a fallback. A small persistent
///   translucent chrome is a cheaper cost than a trap.
class DiagramFullscreenScreen extends StatefulWidget {
  /// Builds the screen. [args] carries the pre-rendered PNG bytes and
  /// the WebView's measured layout size; both are required so the
  /// screen can render crisply without re-invoking the mermaid
  /// pipeline.
  const DiagramFullscreenScreen({required this.args, super.key});

  /// Pre-rendered diagram payload. The screen never recomputes or
  /// replaces this; popping back to the inline viewer restores the
  /// reader's original scroll + pan/zoom state.
  final DiagramFullscreenArgs args;

  @override
  State<DiagramFullscreenScreen> createState() =>
      _DiagramFullscreenScreenState();
}

class _DiagramFullscreenScreenState extends State<DiagramFullscreenScreen>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transform;
  late final AnimationController _resetController;
  Animation<Matrix4>? _resetAnimation;
  bool _isTransformed = false;

  @override
  void initState() {
    super.initState();
    _transform = TransformationController();
    _transform.addListener(_onTransformChanged);
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Immersive sticky lets the system bars slide back briefly when
    // the user swipes from the edge, but auto-hides them again so
    // they never crop the diagram once the gesture completes.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Restore the app-wide baseline that `main.dart` explicitly
    // configures at launch. Keeping the restore target here paired
    // with the baseline at the single cold-start site means any
    // future baseline change (e.g. switching to `manual` to render
    // over a notch-less panel) is a one-file edit in `main.dart`.
    // Reference: code-review CR-20260419-004.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _resetAnimation?.removeListener(_applyResetFrame);
    _resetController.dispose();
    _transform
      ..removeListener(_onTransformChanged)
      ..dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final transformed = !_transform.value.isIdentity();
    if (transformed != _isTransformed) {
      setState(() => _isTransformed = transformed);
    }
  }

  void _resetTransform() {
    HapticFeedback.selectionClick().ignore();
    final tween = Matrix4Tween(
      begin: _transform.value.clone(),
      end: Matrix4.identity(),
    );
    _resetAnimation?.removeListener(_applyResetFrame);
    _resetAnimation = tween.animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    )..addListener(_applyResetFrame);
    _resetController
      ..reset()
      ..forward();
  }

  void _applyResetFrame() {
    final animation = _resetAnimation;
    if (animation == null) return;
    _transform.value = animation.value;
  }

  void _close() {
    HapticFeedback.selectionClick().ignore();
    // `Navigator.maybePop` walks the nearest enclosing navigator
    // (whether the app was wired through `go_router` or a plain
    // `MaterialPageRoute` in a test harness) and is a no-op on a
    // root route — safer than `pop()` when a deep link lands here
    // without a back stack.
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final aspectRatio =
        widget.args.width > 0 && widget.args.height > 0
            ? widget.args.width / widget.args.height
            : 16 / 9;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return PopScope(
      canPop: true,
      // `dispose` restores the baseline SystemUiMode — duplicating
      // the call in `onPopInvokedWithResult` used to double-toggle
      // the chrome on every back-gesture, producing a single-frame
      // flash of the wrong mode on some Android OEM skins.
      // Reference: code-review CR-20260419-004.
      child: Scaffold(
        // Tracks the active reading theme (light / dark / sepia).
        // An earlier version pinned `Colors.black` which crushed
        // contrast on the light + sepia surfaces — a flowchart
        // whose nodes use [ColorScheme.primaryContainer] (a soft
        // warm brown on sepia, a pale blue on light) disappears
        // against pure black, and the reader has to tilt the phone
        // to make out the edges. Using the scheme surface keeps
        // the diagram's own palette — which was already generated
        // from the same [ColorScheme] by [buildMermaidInitDirective]
        // — consistent with the surrounding app chrome.
        backgroundColor: scheme.surface,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // The image itself — pan + pinch zoom live on
            // `InteractiveViewer`. No outer GestureDetector: an
            // earlier version wrapped this in a tap-to-toggle-chrome
            // detector, but a missed tap on the close button hid the
            // close button itself and, with the system bars
            // suppressed by immersive mode, left the user with no
            // affordance to leave the screen.
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 0.5,
                maxScale: 10,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: Image.memory(
                      widget.args.pngBytes,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                      semanticLabel: l10n.mermaidDiagramLabel,
                    ),
                  ),
                ),
              ),
            ),
            // Persistent translucent chrome bar — close on the
            // leading edge, reset on the trailing edge. Reset fades
            // to zero opacity whenever the transform is at identity
            // so the bar does not advertise an affordance that would
            // be a no-op. The close button is always visible so the
            // user can leave the screen from any state.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _ChromeIconButton(
                        icon: Icons.close,
                        tooltip: l10n.diagramFullscreenCloseTooltip,
                        onPressed: _close,
                      ),
                      const Spacer(),
                      AnimatedOpacity(
                        opacity: _isTransformed ? 1 : 0,
                        duration:
                            reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 150),
                        child: IgnorePointer(
                          ignoring: !_isTransformed,
                          child: _ChromeIconButton(
                            icon: Icons.center_focus_strong_outlined,
                            tooltip: l10n.mermaidReset,
                            onPressed: _resetTransform,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tonal 44-dp hit-target icon button used by the fullscreen
/// chrome bar. Uses the active [ColorScheme]'s `surfaceContainerHighest`
/// + `onSurface` so the button reads as an app-chrome affordance on
/// light, dark and sepia themes — same styling the inline
/// [`_DiagramIconButton`] uses on the reading surface, which keeps
/// the two entry points visually paired. Stays 44 × 44 for
/// touch-target compliance even when the visible icon is smaller.
class _ChromeIconButton extends StatelessWidget {
  const _ChromeIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        tooltip: tooltip,
        // Match the inline `_DiagramIconButton` so the fullscreen
        // chrome is visually paired with the inline control the doc
        // comment already claims. Previous `iconSize: 22` produced a
        // 2 px difference on every fullscreen transition.
        // Reference: code-review CR-20260419-016.
        iconSize: 20,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        icon: Icon(icon, color: theme.colorScheme.onSurface),
        onPressed: onPressed,
      ),
    );
  }
}
