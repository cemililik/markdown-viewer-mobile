# ADR-0027: Separate reference-device and hosted performance contracts

- **Status**: Accepted
- **Date**: 2026-07-30
- **Deciders**: Cemil Ilık
- **Owner**: Cemil Ilık
- **Revisit date**: 2026-10-30
- **Amends**:
  [ADR-0026](0026-risk-scoped-integration-and-performance-gates.md), only
  hosted benchmark budget semantics, baseline aggregation, and fixed-profile
  identity
- **Related**:
  [ADR-0024](0024-platform-support-and-responsive-layout.md),
  [ADR-0025](0025-codegen-lint-and-toolchain-maintenance.md)

This ADR separates product performance claims made on reference hardware from
regression signals collected on variably provisioned GitHub-hosted runners.

## Context

ADR-0026 deliberately made the first implementation prove its assumptions with
five fixed-profile calibration runs. The first four complete runs on
`ubuntu-24.04` used the same Flutter, Dart, Java, Android emulator, system
image, virtual hardware configuration, locale, viewport, and benchmark
fixtures. Their results were:

| Metric | Run 1 | Run 2 | Run 3 | Run 4 | Product budget |
|--------|------:|------:|------:|------:|---------------:|
| Open and first-render a 1 MiB document | 7,961.971 ms | 7,196.239 ms | 8,529.813 ms | 8,538.734 ms | < 500 ms |
| Decode and parse a 1 MiB document | 656.661 ms | 524.920 ms | 714.824 ms | 754.839 ms | < 200 ms |
| Build the 1 MiB document widget tree | 7,416.408 ms | 6,566.607 ms | 7,474.551 ms | 7,582.713 ms | < 150 ms |
| Scroll a 10,000-line document | 165.935 ms | 171.276 ms | 154.007 ms | 131.056 ms | ≤ 16.67 ms |
| Highlight a 1,000-line code block | 35.214 ms | 27.974 ms | 36.287 ms | 37.722 ms | < 50 ms |
| Mermaid prewarm plus typical first render | 582.459 ms | 628.665 ms | 571.021 ms | 564.974 ms | < 800 ms |
| Search 500 markdown files | 392.568 ms | 355.973 ms | 640.572 ms | 646.619 ms | < 200 ms |

Each run already aggregates one untimed warm-up and five measured repetitions
as required by ADR-0026. The table therefore compares complete run-level
medians, except for the run-level scrolling p95.

The fifth runner experienced an ADB host-transport failure immediately after
the Flutter VM service became available. The application remained alive, but
`adbd` recorded a socket flush timeout and closed the host transport. This is
an infrastructure failure eligible for the one rerun allowed by ADR-0026, not
a performance result.

The four complete runs exposed two independent problems with the original
decision:

1. The existing product budgets name physical reference devices in the
   [performance standard][performance-standard]. A nested Android emulator on
   a hosted virtual machine is not a Pixel 6a and cannot truthfully pass or
   fail a Pixel 6a product claim.
2. Pinning the guest shape and toolchain does not pin the physical host.
   The maximum run-level value exceeded the minimum by approximately 19
   percent for document open and 82 percent for content search. Even the
   observed guest `MemTotal` differed by 4 KiB between otherwise identical
   emulators.
   Treating volatile observations as exact profile identity would reject valid
   calibration inputs, while using the median of these runners with a
   10-percent threshold would create a gate that its own calibration data
   cannot reliably pass.

This satisfies ADR-0026's revisit criterion for hosted-runner behavior that
prevents the fixed profile from producing a useful regression signal. It does
not justify increasing any product budget. The measurements also do not prove
that a physical Pixel 6a misses a budget, so they are not sufficient evidence
for the separate document-virtualization decision required by roadmap item
`W4-01`.

## Decision

### Maintain two explicit performance contracts

The project maintains two related but non-interchangeable contracts:

1. **Reference-device product budgets** remain the normative user-experience
   targets in the performance standard. They are measured in release mode on
   the named physical device. A hosted-emulator result cannot weaken, satisfy,
   or replace them.
2. **Hosted CI regression gates** run in profile mode on the pinned emulator
   from ADR-0026. They detect material changes relative to measurements from
   the same hosted environment. Their raw values are CI observations, not
   product-budget claims.

Roadmap performance work must report both the hosted regression result and,
when it claims that a product budget is met, release-mode evidence from the
named reference device. A product budget remains unmet until that
reference-device evidence exists.

### Calibrate the hosted upper bound

The hosted baseline is built from exactly five complete, structurally valid
calibration results from independently provisioned runners. Confirmed
infrastructure failures do not count as results and may be rerun once under
ADR-0026's existing failure policy.

For each metric, the baseline value is the maximum of the five complete
run-level values. A later hosted run fails when its run-level value is more
than 10 percent above that baseline value. Exactly 10 percent remains
permitted. Selecting the observed upper bound, instead of the median, makes the
initial tolerance explicit and prevents the baseline from rejecting variation
already demonstrated during calibration.

The maximum-of-five rule is not permission to accept a slower product:

- the physical reference-device budget remains unchanged;
- a hosted baseline increase still requires a dedicated reviewed commit with
  before-and-after evidence and the cause;
- routine reruns cannot replace an identified infrastructure fault; and
- a performance improvement may lower the hosted baseline only through a
  dedicated reviewed calibration commit.

The hosted gate does not apply the physical-device absolute budgets. Applying
those numbers to a different execution environment would produce a permanent
red gate without establishing anything about the actual product target.

### Separate stable identity from volatile observations

The fail-closed result retains two metadata groups:

- **Profile identity** contains fields the workflow controls and compares
  exactly: runner label and operating-system family, Flutter and Dart
  versions, Java version, Android API and system-image fingerprint, emulator
  package and build, architecture, virtual hardware profile, configured cores,
  RAM and heap, observed guest CPU count, Dalvik heap, locale, viewport,
  density, and emulator options.
- **Run observations** contain provenance and useful diagnostics that can vary
  without changing the intended profile: runner image revision, observed guest
  memory in KiB, run identifier, attempt, commit, and timestamp.

Missing, malformed, or unexpected identity fields fail closed. Missing or
malformed required observations also fail closed, but a valid observed value
does not need to equal a previous run's value. This distinction preserves
diagnostic evidence without pretending that GitHub exposes a byte-identical
physical host.

### Preserve release isolation

This amendment changes no release secret, protected environment, signing
command, store-upload action, or release dependency. Hosted benchmarks remain
unsigned and receive no repository secrets. Reference-device evidence must not
reuse or expose signing or store credentials.

### Keep the decision temporary and measurable

The hosted upper-bound strategy remains appropriate only while it provides a
useful, low-noise regression signal. At the revisit date, the owner evaluates:

- false-positive and rerun frequency;
- the spread of raw hosted results by metric;
- whether a larger GitHub-hosted runner with an owned fixed size is available;
- whether a secured self-hosted or physical-device runner is operationally
  justified; and
- whether reference-device measurements show that roadmap performance work
  meets the unchanged product budgets.

## Verification requirements

Before acceptance is implemented:

- five complete calibration results use the same stable profile identity and
  fixture contract;
- a confirmed infrastructure failure is excluded and rerun rather than
  converted into a result;
- the calibrator accepts valid observed guest-memory and runner-image
  variation but rejects stable profile drift;
- every baseline metric equals the maximum of its five run-level values;
- a hosted result exactly 10 percent above baseline passes and a result above
  10 percent fails;
- missing, malformed, partial, negative, or non-finite data still fails
  closed;
- changing a fixture, sample count, aggregation, toolchain pin, emulator pin,
  locale, or viewport still fails closed;
- a deliberately over-baseline result turns the comparator red;
- the physical reference-device budgets remain byte-for-byte unchanged in the
  performance standard;
- benchmark artifacts retain raw values, profile identity, run observations,
  timeline summaries, and comparison reports for 90 days; and
- release secret names, the protected `release` environment, signed build
  commands, and store-upload steps remain unchanged.

## Consequences

### Positive

- CI makes only claims its execution environment can support.
- Pixel 6a and iPhone 12 targets remain strict instead of being inflated to
  accommodate hosted virtualization.
- The initial baseline does not fail on variability already observed in its
  own calibration sample.
- Volatile diagnostics remain available without corrupting fixed-profile
  identity.
- Performance work can lower hosted and reference-device results without
  conflating the two.

### Negative

- A hosted pull-request gate alone cannot prove that a physical-device product
  budget is met.
- The maximum of five calibration values is less sensitive than the median to
  small regressions.
- Reference-device claims require separate owned evidence until suitable
  device automation exists.
- The project must monitor gate sensitivity and revisit the execution
  environment if the hosted spread remains too wide.

### Neutral

- Existing measurements remain evidence of the current hosted implementation,
  not evidence for or against a physical Pixel 6a.
- The later `W4-01` virtualization ADR still requires the measurements and
  dependencies named by that roadmap item.

## Alternatives considered

### Apply physical-device budgets directly to the hosted emulator

Rejected because the first calibration proved that the environments are not
performance-equivalent. A permanently failing check is not a gate and cannot
support a truthful product claim.

### Raise the product budgets to the hosted measurements

Rejected because it would weaken user-experience targets based on unrelated
virtualization overhead and variable host allocation.

### Use the median of five hosted runs

Rejected because the measured spread already exceeds the approved 10-percent
regression threshold. The resulting baseline would classify known calibration
variation as a regression.

### Normalize against a synthetic host microbenchmark

Rejected because one synthetic CPU score cannot safely normalize UI layout,
GPU rasterisation, filesystem, WebView, isolate, and ADB behavior. It could
hide a real pipeline-specific regression.

### Require a self-hosted physical device immediately

Rejected for this implementation because no owned runner, security boundary,
maintenance model, or availability target exists. It remains the preferred
future option when its operational prerequisites are approved.

### Remove the performance gate

Rejected because a conservative hosted regression signal still prevents large
accidental slowdowns and preserves the evidence needed to improve the
measurement environment.

## References

- [ADR-0026: Risk-scoped integration and performance gates][adr-0026]
- [Performance standards][performance-standard]
- [Prioritized roadmap, W1-03, W3-14, W3-15, and W4-01][roadmap]
- [GitHub-hosted runners reference][github-hosted-runners]
- [Self-hosted runners reference][self-hosted-runners]

[adr-0026]: 0026-risk-scoped-integration-and-performance-gates.md
[performance-standard]: ../standards/performance-standards.md
[roadmap]: ../analysis/17-prioritized-roadmap.md
[github-hosted-runners]: https://docs.github.com/actions/reference/runners/github-hosted-runners
[self-hosted-runners]: https://docs.github.com/actions/reference/runners/self-hosted-runners
