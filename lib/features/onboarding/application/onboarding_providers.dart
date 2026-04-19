import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/core/errors/log_and_drop.dart';
import 'package:markdown_viewer/features/onboarding/domain/repositories/onboarding_store.dart';

/// Authoritative version number of the onboarding content.
///
/// Bump this any time the steps in [onboardingScreen] change in a way
/// that returning users should see — added page, rewritten copy,
/// reordered flow, new feature callout. Patch/cosmetic tweaks to an
/// existing step (typo fixes, colour adjustments) should NOT bump it,
/// because a bump re-interrupts every user on their next cold start.
///
/// The router compares this against [OnboardingStore.readSeenVersion]
/// through [shouldShowOnboardingProvider]; a fresh install starts at
/// `0` and is shown the flow once, and every later bump shows the
/// flow exactly once more per user.
const int currentOnboardingVersion = 3;

/// Holds the [OnboardingStore]. Overridden in `main.dart` with an
/// instance backed by the preloaded `SharedPreferences` so the
/// router's synchronous redirect guard can read the seen-version
/// without touching disk.
final onboardingStoreProvider = Provider<OnboardingStore>((ref) {
  throw UnimplementedError(
    'onboardingStoreProvider must be overridden in main.dart',
  );
});

/// Mutable view of the onboarding completion state, expressed as the
/// highest version the user has acknowledged.
///
/// Seeded synchronously from the store on first read so the router's
/// initial redirect can decide where to send the user without an
/// async hop. Calls to [markSeen] update the state immediately and
/// fire-and-forget the disk write — the router's redirect reads the
/// state on every navigation so the in-memory value becoming
/// authoritative before the disk write settles is exactly what we
/// want.
class OnboardingController extends Notifier<int> {
  @override
  int build() {
    final store = ref.watch(onboardingStoreProvider);
    return store.readSeenVersion();
  }

  /// Marks the current onboarding content version as seen. Called
  /// from both the "Get started" button at the end of the flow and
  /// the "Skip" button in the app bar — skipping is treated as an
  /// explicit acknowledgement so the user is not re-interrupted on
  /// their next launch.
  void markSeen() {
    if (state >= currentOnboardingVersion) return;
    state = currentOnboardingVersion;
    dropWithLog(
      ref,
      ref.read(onboardingStoreProvider).writeSeenVersion(state),
      'onboarding.markSeen=$state',
    );
  }

  /// Clears the stored completion marker so the router's redirect
  /// guard re-surfaces the flow on the next navigation. Exposed so
  /// a debug affordance in the settings screen (gated to
  /// `kDebugMode`) can re-trigger onboarding without requiring a
  /// reinstall — previewing a copy or visual change on a physical
  /// device only needs a tap instead of wiping the whole app.
  void reset() {
    state = 0;
    dropWithLog(
      ref,
      ref.read(onboardingStoreProvider).writeSeenVersion(0),
      'onboarding.reset',
    );
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, int>(OnboardingController.new);

/// Whether the onboarding flow should be shown on the next router
/// redirect evaluation.
///
/// Watches the controller so that flipping the state via
/// [OnboardingController.markSeen] invalidates this provider and any
/// consumer (including the router via its `refreshListenable`) sees
/// the new value on the next navigation event.
final shouldShowOnboardingProvider = Provider<bool>((ref) {
  final seen = ref.watch(onboardingControllerProvider);
  return seen < currentOnboardingVersion;
});
