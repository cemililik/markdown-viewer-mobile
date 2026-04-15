import 'dart:async';

import 'package:alchemist/alchemist.dart';

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
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
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
