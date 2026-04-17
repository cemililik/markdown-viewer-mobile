import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// Root test configuration for the entire `test/` directory.
///
/// Flutter's test framework automatically discovers and applies this
/// file to every test under the same directory tree, so this is the
/// single place where cross-cutting test behaviour is declared.
///
/// ## Why Alchemist is configured here
///
/// Alchemist's default behaviour is to run **two** variants of every
/// `goldenTest`: a platform-specific variant that exercises the real
/// host fonts and rendering backend (`goldens/<os>/…`), and a CI
/// variant that uses the bundled "Ahem" font so the resulting image
/// is byte-identical across operating systems (`goldens/ci/…`).
///
/// Only the macOS platform variant is committed to this repository
/// because macOS is the maintainer's development platform. Running
/// the pipeline on a Linux GitHub Actions runner (which is the case
/// for the `ci.yml` lint-and-test job and the `release.yml` verify
/// job) without this config would cause every golden test to fail
/// with a "Could not be compared against non-existent file:
/// goldens/linux/…" error for the Linux platform variant, even
/// though the CI variant passes cleanly.
///
/// Restricting `PlatformGoldensConfig.platforms` to macOS only means:
///
/// - **Local macOS runs:** platform + CI variants both run. A regression
///   in the macOS rendering path surfaces as a diff against
///   `goldens/macos/`.
/// - **Linux / Windows runs (CI):** only the CI variant runs. The CI
///   variant uses the Ahem font + a consistent backend and is the
///   authoritative check for cross-platform rendering correctness.
///
/// If a second maintainer starts running tests on Linux locally and
/// wants to debug pixel-level goldens, add `HostPlatform.linux` to
/// the set and commit the matching `goldens/linux/` fixtures.
///
/// ## Why leak tracking is configured here
///
/// Flutter's `leak_tracker_flutter_testing` package instruments every
/// `testWidgets` call to detect two classes of bug:
///
/// - **`notDisposed`** — a `ChangeNotifier`, `AnimationController`,
///   `TextEditingController`, `Ticker`, etc. was allocated during the
///   test and never had `dispose()` called on it before the test ended.
/// - **`notGCed`** — an object that should have been collected after
///   the test tore down is still reachable, usually because a
///   long-lived singleton (e.g. a provider container, a static map)
///   still holds a reference to a per-test instance.
///
/// Both are real leaks in production — a tab / viewer that hangs onto
/// controllers after navigation accumulates memory on every reopen.
/// Enabling this globally rather than per-test means a newly
/// introduced leak fails the first PR that adds it rather than
/// waiting for a manual profiling pass.
///
/// `notGCed` is intentionally left at its default (enabled only in
/// the opt-in `allLeaks` mode) — it requires forced GCs that inflate
/// test runtime measurably on slow CI runners. When memory profiling
/// uncovers a specific suspect, flip `allNotGCed: true` locally to
/// reproduce.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withTracked(allNotDisposed: true);

  // `HostPlatform` overrides `==` / `hashCode` via Equatable, so a
  // literal `{HostPlatform.macOS}` cannot be declared `const`. Build
  // the set (and the surrounding config) as a runtime value instead.
  final config = AlchemistConfig(
    platformGoldensConfig: PlatformGoldensConfig(
      platforms: {HostPlatform.macOS},
    ),
  );
  await AlchemistConfig.runWithConfig(config: config, run: testMain);
}
