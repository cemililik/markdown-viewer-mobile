import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/features/onboarding/application/onboarding_providers.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';

/// First-run (and post-update) onboarding flow.
///
/// Shown via a `go_router` redirect when
/// [shouldShowOnboardingProvider] returns `true` — i.e. either a
/// brand new install (`seenVersion == 0`) or a user whose last
/// acknowledged version lags behind [currentOnboardingVersion]. Both
/// the "Skip" action in the app bar and the "Get started" button on
/// the final page route back to the library after flipping the
/// stored version through [OnboardingController.markSeen]; the
/// router redirect then re-evaluates and allows the navigation to
/// land on [LibraryRoute] instead of bouncing back into onboarding.
///
/// ## Visual system
///
/// - **Gradient surface** that leans on the page's accent
///   `*Container` Material 3 role so the whole screen tints warmly
///   towards each step's message without introducing any hard-coded
///   hex colours. Transitions between pages are driven by an
///   [AnimatedContainer] that tweens the gradient colours as the
///   user advances.
/// - **Pulsing hero icon** in a large coloured disc — a low-amplitude
///   scale loop (1.0 ↔ 1.04) powered by a `repeat(reverse: true)`
///   [AnimationController].
/// - **Floating decorative icons** orbit the hero at three fixed
///   anchor points, each reinforcing a concept from the page's copy
///   (tables / code / math on the rendering page, font / theme /
///   language on the personalize page, etc).
/// - **Entrance animation** (fade + slide-up) on the title and body
///   every time the PageView settles on a new index, so the copy
///   "arrives" rather than snapping in.
/// - **Animated page indicators** — the active dot widens to a 28 px
///   pill while inactive dots stay as 8 px circles.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  /// Drives the slow pulse of the hero icon. Re-uses a single
  /// controller across page changes — the animation runs against
  /// whichever hero icon is currently on screen.
  late final AnimationController _pulseController;

  /// Drives the fade-in / slide-up of the title + body text on each
  /// page change. Reset and re-forwarded every time
  /// [PageView.onPageChanged] fires.
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync the controllers with the platform "Reduce Motion" flag
    // here rather than inside `build`. `didChangeDependencies` fires
    // on first mount and any time the inherited widgets (MediaQuery)
    // change — which includes the accessibility flag toggling — and
    // unlike `build` it is the correct place to mutate animation
    // controllers, per Flutter's framework contract (mutating state
    // during build throws in debug).
    _syncMotionControllers(disabled: MediaQuery.disableAnimationsOf(context));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  /// Marks the current content version as seen and returns the user
  /// to the library. Both "Skip" and "Get started" route through
  /// here so the tap handlers stay symmetric — skipping is treated
  /// as an explicit acknowledgement, not a defer.
  void _finish() {
    HapticFeedback.mediumImpact().ignore();
    ref.read(onboardingControllerProvider.notifier).markSeen();
    // Use `go` (not `push`) so onboarding is not left sitting in the
    // navigation stack — a back gesture from the library should
    // take the user out of the app, not back into the flow they
    // just dismissed.
    context.go(LibraryRoute.location());
  }

  void _advance() {
    HapticFeedback.selectionClick().ignore();
    final lastIndex = _onboardingSteps.length - 1;
    if (_currentIndex >= lastIndex) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    // Replay the entrance animation so the new page's copy fades /
    // slides in rather than snapping to place.
    _entranceController
      ..reset()
      ..forward();
    HapticFeedback.selectionClick().ignore();
  }

  /// Aligns the pulse + entrance controllers with the platform
  /// "Reduce Motion" preference. When [disabled] is true the pulse
  /// loop stops at rest and the entrance controller snaps to 1.0,
  /// so downstream Animation-driven widgets render their final
  /// state without any time-driven tween.
  void _syncMotionControllers({required bool disabled}) {
    if (disabled) {
      if (_pulseController.isAnimating) {
        _pulseController
          ..stop()
          ..value = 0;
      }
      if (_entranceController.status != AnimationStatus.completed) {
        _entranceController.value = 1;
      }
    } else {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      if (_entranceController.status == AnimationStatus.dismissed) {
        _entranceController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final isLastPage = _currentIndex == _onboardingSteps.length - 1;
    final currentStep = _onboardingSteps[_currentIndex];
    final currentAccent = _accentFor(currentStep.accent, colorScheme);
    // Respect the platform "Reduce Motion" / "Remove Animations"
    // preference. When enabled, every time-driven animation on this
    // screen collapses to zero duration so the cross-fade gradient,
    // pulsing hero, orbiting chips, and entrance tween all render
    // as static state changes. Controller mutation happens in
    // [didChangeDependencies] (the correct hook for MediaQuery-
    // driven side effects); `build` only reads the flag.
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      body: AnimatedContainer(
        duration:
            disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              Color.alphaBlend(
                currentAccent.container.withValues(alpha: 0.45),
                colorScheme.surface,
              ),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _SkipBar(
                onSkip: _finish,
                label: l10n.onboardingSkip,
                visible: !isLastPage,
                accentColor: currentAccent.accent,
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _onboardingSteps.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final step = _onboardingSteps[index];
                    final accent = _accentFor(step.accent, colorScheme);
                    return _OnboardingPageView(
                      step: step,
                      accent: accent,
                      l10n: l10n,
                      textTheme: theme.textTheme,
                      pulse: _pulseController,
                      entrance: _entranceController,
                    );
                  },
                ),
              ),
              _PageIndicator(
                count: _onboardingSteps.length,
                currentIndex: _currentIndex,
                activeColor: currentAccent.accent,
                inactiveColor: colorScheme.outlineVariant,
                semanticsLabel: l10n.onboardingPageIndicator(
                  _currentIndex + 1,
                  _onboardingSteps.length,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _advance,
                    style: FilledButton.styleFrom(
                      backgroundColor: currentAccent.accent,
                      foregroundColor: currentAccent.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isLastPage
                          ? l10n.onboardingGetStarted
                          : l10n.onboardingNext,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: currentAccent.onAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Accent palette ────────────────────────────────────────────────────

/// Which Material 3 colour family a given onboarding page leans on.
///
/// Keeping this as an enum (rather than resolved `Color` values baked
/// into the step list) lets the steps stay `const` while the accent
/// colours are still looked up against the live [ColorScheme] at
/// build time — so a light/dark theme flip inside the onboarding
/// flow immediately retints the hero, the gradient, and the CTA
/// without rebuilding the manifest.
enum _AccentRole { primary, secondary, tertiary }

class _Accent {
  const _Accent({
    required this.accent,
    required this.onAccent,
    required this.container,
    required this.onContainer,
  });

  final Color accent;
  final Color onAccent;
  final Color container;
  final Color onContainer;
}

_Accent _accentFor(_AccentRole role, ColorScheme scheme) {
  switch (role) {
    case _AccentRole.primary:
      return _Accent(
        accent: scheme.primary,
        onAccent: scheme.onPrimary,
        container: scheme.primaryContainer,
        onContainer: scheme.onPrimaryContainer,
      );
    case _AccentRole.secondary:
      return _Accent(
        accent: scheme.secondary,
        onAccent: scheme.onSecondary,
        container: scheme.secondaryContainer,
        onContainer: scheme.onSecondaryContainer,
      );
    case _AccentRole.tertiary:
      return _Accent(
        accent: scheme.tertiary,
        onAccent: scheme.onTertiary,
        container: scheme.tertiaryContainer,
        onContainer: scheme.onTertiaryContainer,
      );
  }
}

// ── Step manifest ─────────────────────────────────────────────────────

/// A single onboarding step — hero icon, three decorative floating
/// icons, accent role, and l10n getters for the title + body copy.
/// Kept private to the presentation layer so bumping
/// [currentOnboardingVersion] and updating the list happens in one
/// file, with no cross-layer ceremony.
class _OnboardingStep {
  const _OnboardingStep({
    required this.heroIcon,
    required this.floatingIcons,
    required this.accent,
    required this.title,
    required this.body,
  });

  /// Icon shown in the large central disc.
  final IconData heroIcon;

  /// Three decorative icons positioned in a triangular pattern
  /// around the hero disc, each reinforcing a concept from the
  /// page's copy. Exactly three — the triangular layout would
  /// rebalance awkwardly with a different count.
  final List<IconData> floatingIcons;

  /// Which Material 3 accent family this page leans on. Pages
  /// rotate through primary → secondary → tertiary → primary so
  /// returning users get a sense of visual progress.
  final _AccentRole accent;

  /// Title getter — a function so the const list can be declared
  /// once and pick up whichever locale is active at build time.
  final String Function(AppLocalizations l10n) title;

  /// Body getter with the same rationale as [title].
  final String Function(AppLocalizations l10n) body;
}

/// Declarative manifest of every onboarding page.
///
/// **Editing this list is a content change.** If the edit is
/// user-facing (new page, rewritten copy, reordered flow), bump
/// [currentOnboardingVersion] in
/// `application/onboarding_providers.dart` so every returning user
/// sees the updated flow exactly once on their next cold start.
const List<_OnboardingStep> _onboardingSteps = <_OnboardingStep>[
  _OnboardingStep(
    heroIcon: Icons.menu_book_outlined,
    floatingIcons: <IconData>[
      Icons.star_outline_rounded,
      Icons.bookmark_outline_rounded,
      Icons.search_rounded,
    ],
    accent: _AccentRole.primary,
    title: _welcomeTitle,
    body: _welcomeBody,
  ),
  _OnboardingStep(
    heroIcon: Icons.auto_awesome_outlined,
    floatingIcons: <IconData>[
      Icons.table_chart_outlined,
      Icons.code_rounded,
      Icons.functions_rounded,
    ],
    accent: _AccentRole.secondary,
    title: _renderingTitle,
    body: _renderingBody,
  ),
  _OnboardingStep(
    heroIcon: Icons.tune_rounded,
    floatingIcons: <IconData>[
      Icons.text_fields_rounded,
      Icons.dark_mode_outlined,
      Icons.translate_rounded,
    ],
    accent: _AccentRole.tertiary,
    title: _personalizeTitle,
    body: _personalizeBody,
  ),
  _OnboardingStep(
    heroIcon: Icons.folder_open_outlined,
    floatingIcons: <IconData>[
      Icons.cloud_download_outlined,
      Icons.description_outlined,
      Icons.hub_outlined,
    ],
    accent: _AccentRole.primary,
    title: _getStartedTitle,
    body: _getStartedBody,
  ),
];

String _welcomeTitle(AppLocalizations l10n) => l10n.onboardingWelcomeTitle;
String _welcomeBody(AppLocalizations l10n) => l10n.onboardingWelcomeBody;
String _renderingTitle(AppLocalizations l10n) => l10n.onboardingRenderingTitle;
String _renderingBody(AppLocalizations l10n) => l10n.onboardingRenderingBody;
String _personalizeTitle(AppLocalizations l10n) =>
    l10n.onboardingPersonalizeTitle;
String _personalizeBody(AppLocalizations l10n) =>
    l10n.onboardingPersonalizeBody;
String _getStartedTitle(AppLocalizations l10n) =>
    l10n.onboardingGetStartedTitle;
String _getStartedBody(AppLocalizations l10n) => l10n.onboardingGetStartedBody;

// ── Private widgets ───────────────────────────────────────────────────

class _SkipBar extends StatelessWidget {
  const _SkipBar({
    required this.onSkip,
    required this.label,
    required this.visible,
    required this.accentColor,
  });

  final VoidCallback onSkip;
  final String label;
  final bool visible;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    // A fixed-height bar keeps the PageView vertically stable when
    // the Skip button fades out on the last page — otherwise the
    // layout would jump by the button's height just as the user
    // reaches the "Get started" moment.
    return SizedBox(
      height: 56,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !visible,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Semantics(
                // TextButton already announces as a button but the
                // label parameter pins the spoken text to the
                // localized "Skip" / "Atla" string regardless of any
                // future styling that might wrap the child in a
                // decorator that interferes with auto-label pickup.
                button: true,
                label: label,
                child: TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(foregroundColor: accentColor),
                  child: Text(label),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({
    required this.step,
    required this.accent,
    required this.l10n,
    required this.textTheme,
    required this.pulse,
    required this.entrance,
  });

  final _OnboardingStep step;
  final _Accent accent;
  final AppLocalizations l10n;
  final TextTheme textTheme;
  final AnimationController pulse;
  final AnimationController entrance;

  @override
  Widget build(BuildContext context) {
    // Fade + slide-up tweens for the entrance animation. The body
    // text is delayed behind the title so the two pieces of copy
    // don't land on the screen simultaneously.
    final titleFade = CurvedAnimation(
      parent: entrance,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    );
    final bodyFade = CurvedAnimation(
      parent: entrance,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _HeroCluster(step: step, accent: accent, pulse: pulse),
          const SizedBox(height: 48),
          _EntranceSlide(
            animation: titleFade,
            child: Text(
              step.title(l10n),
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _EntranceSlide(
            animation: bodyFade,
            child: Text(
              step.body(l10n),
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade + 24 px slide-up wrapper applied to each piece of page copy.
/// The parent page rebuilds on every tick of [animation], so the
/// child widget can stay a simple `Text` — no Tween plumbing leaks
/// into the step manifest.
class _EntranceSlide extends StatelessWidget {
  const _EntranceSlide({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, innerChild) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - animation.value)),
            child: innerChild,
          ),
        );
      },
      child: child,
    );
  }
}

/// The big circle + orbiting floating icons that dominate the top
/// half of each page.
///
/// Sized against a fixed 260 px square so the positional anchors
/// for the three floating chips don't need to be recomputed per
/// screen width — the whole cluster sits in the centre of the
/// page column and scales visually through its surrounding padding
/// on narrower devices.
class _HeroCluster extends StatelessWidget {
  const _HeroCluster({
    required this.step,
    required this.accent,
    required this.pulse,
  });

  final _OnboardingStep step;
  final _Accent accent;
  final AnimationController pulse;

  static const double _clusterSize = 260;
  static const double _heroSize = 136;
  static const double _chipSize = 56;

  @override
  Widget build(BuildContext context) {
    // Positional anchors for the three floating chips, laid out in
    // a loose triangular pattern around the hero disc. Coordinates
    // are offsets from the cluster's centre, in the range
    // [-1.0, 1.0] where ±1.0 is the cluster edge.
    const anchors = <Offset>[
      Offset(-0.82, -0.55), // top-left
      Offset(0.85, -0.35), // top-right (slightly lower)
      Offset(0.15, 0.92), // bottom-centre
    ];
    assert(
      step.floatingIcons.length == anchors.length,
      'Each onboarding step must have exactly ${anchors.length} floating icons',
    );

    return SizedBox(
      width: _clusterSize,
      height: _clusterSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft glow behind the hero, built from the same container
          // colour as the disc but at a lower alpha. Gives the hero
          // some depth without needing a BoxShadow (which doesn't
          // respect circular clipping as cleanly on Android).
          Container(
            width: _clusterSize,
            height: _clusterSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.container.withValues(alpha: 0.55),
                  accent.container.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.75],
              ),
            ),
          ),
          // Hero disc with the main icon, scaled by the pulse
          // controller. The scale range is deliberately narrow
          // (1.00 → 1.04) so the motion reads as "breathing", not
          // bouncing.
          AnimatedBuilder(
            animation: pulse,
            builder: (context, _) {
              final scale = 1.0 + (pulse.value * 0.04);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: _heroSize,
                  height: _heroSize,
                  decoration: BoxDecoration(
                    color: accent.container,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accent.accent.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    step.heroIcon,
                    size: 64,
                    color: accent.onContainer,
                  ),
                ),
              );
            },
          ),
          // Floating decorative chips positioned via the anchors
          // above. Each one breathes on a slight phase offset from
          // the hero so the whole cluster looks alive rather than
          // marching in lock-step.
          for (var i = 0; i < step.floatingIcons.length; i++)
            Positioned(
              left: _chipLeftFor(anchors[i]),
              top: _chipTopFor(anchors[i]),
              child: _FloatingChip(
                icon: step.floatingIcons[i],
                accent: accent,
                pulse: pulse,
                phase: i * (math.pi / 3),
              ),
            ),
        ],
      ),
    );
  }

  double _chipLeftFor(Offset anchor) {
    const centreX = _clusterSize / 2;
    return centreX +
        (anchor.dx * (_clusterSize / 2 - _chipSize / 2)) -
        _chipSize / 2;
  }

  double _chipTopFor(Offset anchor) {
    const centreY = _clusterSize / 2;
    return centreY +
        (anchor.dy * (_clusterSize / 2 - _chipSize / 2)) -
        _chipSize / 2;
  }
}

class _FloatingChip extends StatelessWidget {
  const _FloatingChip({
    required this.icon,
    required this.accent,
    required this.pulse,
    required this.phase,
  });

  final IconData icon;
  final _Accent accent;
  final AnimationController pulse;

  /// Radian offset so each chip breathes slightly out of phase with
  /// the hero and with the other chips. Keeps the cluster from
  /// looking mechanically synchronised.
  final double phase;

  @override
  Widget build(BuildContext context) {
    // Floating chips are purely decorative — the icons (`description`,
    // `menu_book`, etc.) convey no information beyond visual
    // atmosphere. Excluding them from the semantics tree stops
    // TalkBack / VoiceOver from announcing six irrelevant icon names
    // before the user reaches the actual page copy.
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, _) {
          // Independent sine wave — each chip drifts up to 3 px on its
          // own schedule even though they all share the single
          // `_pulseController` for cheapness.
          final drift = math.sin((pulse.value * math.pi * 2) + phase) * 3;
          return Transform.translate(
            offset: Offset(0, drift),
            child: Container(
              width: _HeroCluster._chipSize,
              height: _HeroCluster._chipSize,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.accent.withValues(alpha: 0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 24, color: accent.accent),
            ),
          );
        },
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.count,
    required this.currentIndex,
    required this.activeColor,
    required this.inactiveColor,
    required this.semanticsLabel,
  });

  final int count;
  final int currentIndex;
  final Color activeColor;
  final Color inactiveColor;

  /// Localized "page N of total" string read aloud as the single
  /// semantics node for the whole dot row.
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    // The dots are a single logical "position indicator" to a screen
    // reader — announcing six separate pill widgets produces noise,
    // so the whole row speaks as one node with a "page N of total"
    // label. The individual containers are excluded to prevent
    // duplicate announcements.
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (index) {
            final isActive = index == currentIndex;
            return AnimatedContainer(
              duration:
                  disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: isActive ? 28 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? activeColor : inactiveColor,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ),
    );
  }
}
