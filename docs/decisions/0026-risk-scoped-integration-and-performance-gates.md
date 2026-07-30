# ADR-0026: Risk-scoped integration and performance gates

- **Status**: Accepted
- **Date**: 2026-07-30
- **Deciders**: Cemil Ilık
- **Owner**: Cemil Ilık
- **Revisit date**: 2026-10-30
- **Amends**:
  [ADR-0010](0010-testing-strategy.md), only its consequence that integration
  tests gate release builds but not pull requests
- **Related**: [ADR-0015](0015-mermaid-rendering-and-sandbox-v2.md),
  [ADR-0024](0024-platform-support-and-responsive-layout.md),
  [ADR-0025](0025-codegen-lint-and-toolchain-maintenance.md)

This ADR defines deterministic mobile integration and performance gates while
preserving the existing signed-release and store-delivery path.

## Context

ADR-0010 establishes a layered test strategy and states in its consequences
that integration tests gate release builds only so pull-request CI remains
fast. The binding [testing standard][testing-standard] repeats that release-only
rule and requires critical integration coverage on both Android and iOS. The
binding [performance standard][performance-standard] separately requires the
benchmark suite on every pull request against `main`.

The approved roadmap makes the conflict concrete:

- `W1-02` requires an emulator or simulator job on every pull request that
  touches the viewer and on every release tag; and
- `W1-03` requires a fixed-device benchmark job with enforced budgets,
  regression comparison, and retained history.

No workflow currently executes `integration_test/`. The real Mermaid path
therefore has no CI coverage for the bundled JavaScript asset, native WebView,
sandbox initialization, JavaScript channel, screenshot, or PNG result. Widget
tests cannot substitute for this boundary because Flutter integration tests
run the built application on a target device or operating-system emulator.

Performance tests have a different failure model. They must run in profile
mode and emit machine-readable measurements, but GitHub-hosted runner images
receive regular software updates. A raw single timing on a floating runner is
not a stable merge gate. The device profile, toolchain, warm-up, repetitions,
aggregation, baseline, and absolute product budgets all need explicit
ownership.

The existing tag workflow already signs Android and iOS artifacts with
repository secrets and sends them to the stores. Adding quality gates must not
move, rename, duplicate, or broaden access to those secrets, and must not
replace the working store-upload steps or protected `release` environment.

## Decision

### Separate correctness from measurement

The mobile suites have two explicit roles:

1. **Critical integration tests** prove deterministic end-to-end behavior.
   They include the real Mermaid render path and may add critical file-open,
   rendered search, and export scenarios. They do not assert noisy relative
   timing relationships such as "the second call was faster."
2. **Performance benchmarks** measure document open, scrolling, syntax
   highlighting, Mermaid cold render, and content search. They emit structured
   JSON and are evaluated by a separate budget tool.

Correctness failures and budget failures remain independently visible in CI.
A benchmark cannot hide a functional assertion, and a functional retry cannot
erase a performance sample.

### Pull-request gates

Every pull request targeting `main` starts a stable integration-gate check.
The check determines affected paths inside the running workflow rather than
using a workflow-level path filter, so branch protection always receives a
conclusion.

Critical integration tests run on the pinned Android emulator when a pull
request changes any of these surfaces:

- `lib/features/viewer/**`;
- Mermaid assets or their verified fetch tooling;
- `integration_test/**` or its drivers and budget tooling;
- Flutter dependencies or the lockfile;
- Android or iOS viewer/plugin integration;
- the integration, benchmark, or release workflows; or
- a shared rendering, localization, theme, or platform-channel contract used
  by the viewer.

The path classifier is covered by table-driven tests. An unrecognized or
unparseable change set fails closed by running the critical suite.

The Android performance benchmark runs on every pull request targeting `main`,
as required by the [performance standard][performance-standard]. This broader
scope is intentional: dependencies, application startup, shared rendering
code, platform integration, and toolchain changes can regress measured
behavior without changing a viewer-owned path. The benchmark may share one
prepared emulator with the critical suite, but a skipped critical step must
not skip the benchmark.

### Release-tag gates

Every `v*` release tag runs the critical integration suite on both:

- a pinned Android emulator; and
- the pinned iOS 26.4 simulator and Xcode 26.4.1 selected by ADR-0024 and
  available on GitHub's `macos-26` runner.

The Android tag gate also runs the performance benchmark. Android and iOS
signed-build jobs wait for their corresponding integration gate, and store
delivery cannot start after a failed, cancelled, or timed-out gate.

This changes only job dependencies and adds unsigned test jobs. The following
release properties are invariants:

- repository secret names and their source remain unchanged;
- the protected `release` environment remains attached to the existing signed
  Android and iOS jobs;
- signing, versioning, artifact, Google Play, App Store Connect, and GitHub
  Release steps remain intact;
- integration and benchmark jobs receive no signing, store, Sentry, or
  credential secrets; and
- no test artifact is promoted into a signed or store-delivered artifact.

CI verifies these invariants by comparing the release workflow's secret
references, environments, signed build commands, and upload steps against an
explicit contract.

### Fixed Android benchmark profile

The benchmark gate uses a literal Ubuntu runner, Flutter version, Android API
level, system-image target, CPU architecture, hardware profile, core count,
RAM, heap, locale, display size, density, and emulator options. Hardware
acceleration is enabled explicitly. Animations, audio, camera, boot animation,
and snapshot persistence are disabled.

All third-party Actions are pinned to full commit SHAs. The Android emulator
action is configuration only; it receives no credentials. CI records the
GitHub runner image version, Flutter and Dart versions, Java version, Android
emulator version, system-image identifier, and device configuration beside
every result.

Performance runs use Flutter profile mode with DDS disabled, following
Flutter's integration-performance guidance. Each metric has one untimed
warm-up followed by five measured repetitions. The gate uses the median for
latency metrics and the 95th percentile for frame-time metrics. Test fixtures,
query text, viewport, scroll gesture, and starting application state are
deterministic and version controlled.

### Budgets, baselines, and history

The first accepted implementation records a versioned JSON baseline from five
complete green calibration runs on the fixed profile. Every later run fails if
either:

- an absolute budget is exceeded; or
- a metric regresses by more than 10 percent from its versioned baseline.

The initial enforced product budgets are:

| Metric | Absolute budget |
|--------|-----------------|
| Open and first-render a 1 MiB document | `< 500 ms` |
| Decode and parse a 1 MiB document | `< 200 ms` |
| Build the 1 MiB document widget tree | `< 150 ms` |
| Scroll a 10,000-line document | `p95 frame time ≤ 16.67 ms` |
| Highlight a 1,000-line code block | `< 50 ms` |
| Mermaid prewarm plus typical first render | `< 800 ms` |
| Search a representative library of 500 markdown files | `< 200 ms` |

The benchmark records fixture sizes and counts in its result so a smaller or
truncated corpus cannot create a false improvement. UTF-8 fixtures use
`utf8.encode`, never `String.codeUnits`, because Dart exposes UTF-16 code units
and treating them as file bytes corrupts non-ASCII and surrogate-pair content.

The comparison tool validates the schema, metric set, units, device profile,
sample count, and baseline provenance before comparing values. Missing,
non-finite, negative, partial, differently configured, or stale results fail
closed.

Raw results, the comparison report, and Flutter timeline summaries are
uploaded on success and failure with 90-day retention. The versioned baseline
provides durable review history; workflow artifacts provide per-run trend
evidence. A baseline may change only in a dedicated reviewed commit containing
before/after measurements and a reason. It cannot be regenerated automatically
from the pull request under test.

A budget increase or a regression above 10 percent still requires the review
and justification mandated by the
[performance standard][performance-standard]. Re-running a failed benchmark
without an identified infrastructure fault is not an approval mechanism.

### Failure and timeout policy

- A failed assertion, missing result, device boot failure, timeout, or
  malformed report makes the gate red.
- Correctness tests are not automatically retried.
- A confirmed GitHub or emulator infrastructure incident may be rerun once;
  both attempts remain visible.
- Integration and benchmark commands have explicit suite and workflow
  timeouts.
- Failure artifacts include Flutter logs, device logs, screenshots where they
  contain no user data, structured benchmark output, and timeline summaries.
- Test fixtures contain synthetic repository and document data only.

### Verification

Implementation verification requires automated proof that:

- the real Mermaid integration test goes red when rendering is deliberately
  broken;
- a viewer-touching pull request runs the Android critical suite;
- an unrelated documentation-only pull request concludes the critical gate
  without allocating an emulator;
- an unknown path-classification case runs the critical suite;
- every pull request runs the fixed-profile benchmark;
- a `v*` tag runs Android and iOS critical suites before signed builds;
- release integration jobs cannot read repository secrets;
- the repository secret inventory, protected environment, build commands, and
  store upload steps are unchanged;
- profile mode and `--no-dds` are present in the benchmark command;
- device and toolchain metadata match the baseline profile;
- all required metrics and five measured samples are present;
- an absolute-budget breach fails;
- a regression of more than 10 percent fails;
- exactly 10 percent does not fail because the
  [performance standard][performance-standard] says "more than";
- missing or malformed JSON fails;
- `.codeUnits` cannot reappear in benchmark fixture encoding;
- test timeouts and the `golden` tag behavior are executable checks; and
- success and failure both retain the required artifacts.

Before this roadmap step is complete, the implementation records one
deliberately broken correctness run that proves the integration gate turns red
and one deliberately over-budget result that proves the comparator turns red.
The intentional failures are then reverted and both gates must pass.

## Revisit criteria

Revisit this decision before the scheduled date if:

- the product adopts a sustained 120 Hz scrolling target and needs a separate
  8.33 ms frame-time tier;
- hosted-runner or emulator changes prevent the fixed profile from producing a
  useful regression signal; or
- CI duration or reliability data supports a different gate split without
  weakening pull-request or release protection.

## Consequences

### Positive

- The real WebView boundary fails before a viewer regression can merge or
  reach a store build.
- Both mobile platforms protect release tags without charging every pull
  request for two simulator builds.
- Performance claims become measured contracts with absolute and relative
  enforcement.
- Versioned baselines cannot silently bless the code under test.
- Branch protection receives a stable result even when the critical suite is
  not applicable.
- Existing repository secrets and store delivery remain isolated from test
  jobs.

### Negative

- Every pull request pays for one Android profile benchmark, increasing CI
  minutes and potentially the wall-clock critical path.
- Viewer-sensitive pull requests pay an additional integration-test duration.
- Release tags wait for Android and iOS simulator capacity before signing.
- GitHub runner-image updates can legitimately invalidate a performance
  baseline and require a measured maintenance commit.
- Five repetitions and retained timelines consume more CI time and artifact
  storage than single-sample tests.

### Neutral

- The fixed emulator is a regression instrument, not a claim that hosted
  virtualized hardware is identical to a physical Pixel 6a.
- Reference-device checks remain appropriate before a production release, but
  they cannot replace the automated regression gate.
- This ADR does not authorize changes to signing credentials, store
  destinations, release environments, or distribution tracks.

## Alternatives considered

### Keep integration tests release-only

Rejected because a broken Mermaid boundary would be discovered after merge,
when diagnosis is more expensive and the release tag is already blocked.

### Run Android and iOS integration suites on every pull request

Rejected because the additional simulator build cost is disproportionate for
non-viewer changes. Android protects affected pull requests; both platforms
protect release tags.

### Use workflow-level path filters

Rejected because a skipped workflow may not publish the stable required check
expected by branch protection. The workflow starts and classifies paths
internally.

### Measure in debug mode

Rejected because debug compilation and instrumentation do not represent
end-user performance. Flutter's official recipe uses profile mode for this
reason.

### Gate only on absolute budgets

Rejected because a meaningful regression can remain below a generous absolute
ceiling.

### Gate only against the previous baseline

Rejected because repeatedly accepting slower baselines would permit
unbounded performance decay while every individual change stayed within 10
percent.

### Generate the baseline from the pull request under test

Rejected because the regression would become its own reference and always
pass.

### Move the suites to an external device-testing service

Rejected for this step because it adds credentials, cost, network processors,
and another operational dependency. The pinned GitHub-hosted emulator and
simulator cover the current critical boundary without expanding the release
secret surface.

## References

- [Flutter integration testing][flutter-integration]
- [Flutter performance measurement with integration tests][flutter-profile]
- [GitHub-hosted runner image lifecycle][github-runner-images]
- [GitHub required-check behavior for filtered workflows][github-status-checks]
- [Android Emulator Runner configuration][android-emulator-runner]
- [GitHub Actions `macos-26` installed-software inventory][github-macos-26]

[flutter-integration]: https://docs.flutter.dev/testing/integration-tests
[flutter-profile]: https://docs.flutter.dev/cookbook/testing/integration/profiling
[github-runner-images]: https://docs.github.com/en/actions/concepts/runners/github-hosted-runners
[github-status-checks]: https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs
[android-emulator-runner]: https://github.com/ReactiveCircus/android-emulator-runner
[github-macos-26]: https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md
[testing-standard]: ../standards/testing-standards.md
[performance-standard]: ../standards/performance-standards.md
