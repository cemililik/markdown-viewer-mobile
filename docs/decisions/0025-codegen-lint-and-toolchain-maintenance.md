# ADR-0025: Codegen, Riverpod lint, and toolchain maintenance

- **Status**: Accepted
- **Date**: 2026-07-30
- **Deciders**: Cemil Ilık
- **Owner**: Cemil Ilık
- **Revisit date**: 2026-10-30
- **Supersedes**: only the temporary `custom_lint` and
  `riverpod_lint` removal and its revisit criteria in
  [ADR-0013](0013-codegen-ecosystem-alignment.md)
- **Related**: [ADR-0002](0002-state-management-riverpod.md)

This ADR replaces an open-ended temporary exception with a tested lint and
toolchain maintenance policy.

## Context

ADR-0013 removed both `custom_lint` and `riverpod_lint` because the versions
available at the time required incompatible analyzer ranges. It did not assign
an owner, date, or recurring compatibility probe, so a temporary loss of
Riverpod-specific checks can persist indefinitely.

The upstream architecture has since changed. `riverpod_lint` 3.1 no longer uses
`custom_lint`; it uses Dart's analysis-server plugin mechanism directly.
Compatible releases exist for the Riverpod 3.2 and analyzer 9 toolchain pinned
by this repository. `custom_lint` is not otherwise needed because the
repository does not define a custom lint package.

The project also needs one policy for Flutter, Dart, analyzer, Riverpod,
Freezed, and generator upgrades. Those packages share resolution and generated
output boundaries, so a version bump is not complete when `pub get` alone
succeeds.

## Decision

### Riverpod lint returns without `custom_lint`

The project reintroduces a `riverpod_lint` release compatible with the pinned
Flutter, Dart, Riverpod, and analyzer versions. It is configured through Dart's
analysis-server plugin mechanism and runs in local analysis and CI.

The gate is proven by a small fixture that intentionally violates one enabled,
stable Riverpod rule. CI must fail while the violation exists and pass when it
is corrected. A plugin that resolves but emits no diagnostics does not satisfy
this decision.

The initial enabled set covers correctness and lifecycle rules, including:

- missing root `ProviderScope`;
- invalid generated-provider dependencies;
- use of `BuildContext` in generated providers;
- invalid provider family parameters;
- unsafe `ref` use during state disposal; and
- keep-alive dependencies inside auto-dispose providers.

Rule severity is recorded in `analysis_options.yaml`. A rule is disabled only
with a repository-wide rationale and a regression fixture where practical.
Source-level ignores follow the coding standard and explain why the rule does
not apply.

`custom_lint` remains absent. It is added only if the project adopts a package
that still requires it or creates a reviewed custom-lint package with at least
one enforced rule. An unused lint runner is not retained as architectural
intent.

### Generated-provider convention

Public providers use the generated Riverpod convention selected by ADR-0002
and ADR-0013. Manual providers remain only where the generator cannot express a
required override, family, lifecycle, or test seam. Each exception is private
where possible and carries a short reason.

Generated files are committed. A codegen check runs the repository's pinned
generator command and fails when the working tree changes. Contributors never
edit generated output directly.

### Toolchain upgrade unit

Flutter, Dart, analyzer, Riverpod, Freezed, Drift, `build_runner`, and their
generators are treated as one compatibility unit. A pull request that changes
one member must:

1. resolve with the committed lockfile policy;
2. regenerate from a clean generated state;
3. produce no unexplained generated diff on a second run;
4. pass Dart and Riverpod analysis;
5. pass unit, widget, golden, integration, and native contract tests affected
   by the change; and
6. record migrations, deprecated APIs, minimum platform changes, and artifact
   size changes.

The CI Flutter version is a literal. Local bootstrap verifies that version
instead of accepting any newer stable SDK. A scheduled compatibility workflow
may test the newest stable Flutter release, but it cannot update the release
pin or lockfile without a reviewed pull request.

### Recurring probe and ownership

The owner reviews the matrix on the first scheduled dependency run after each
calendar quarter and whenever Flutter stable changes analyzer major version.
The probe records:

- the pinned and candidate Flutter and Dart versions;
- analyzer and analysis-server plugin versions;
- Riverpod runtime, annotation, generator, and lint versions;
- Freezed, Drift, router, and serializer generator versions;
- resolution success;
- clean code generation;
- lint-fixture success; and
- all incompatible constraints with upstream issue links when available.

The next mandatory review is **2026-10-30**. A failed candidate probe is a
visible scheduled-workflow result and maintenance issue, not a reason to
disable the pinned release gate.

### Verification

Acceptance requires:

- `riverpod_lint` resolves without `custom_lint`;
- the intentional-violation fixture proves that CI executes the plugin;
- every provider declaration complies or has a reviewed exception;
- code generation is idempotent from a clean checkout;
- the pinned SDK is identical across CI, bootstrap, and documentation; and
- the scheduled compatibility probe emits the complete matrix without
  mutating the release lockfile.

## Consequences

### Positive

- The temporary lint exception ends when upstream compatibility makes that
  possible.
- Provider lifecycle and dependency mistakes become CI failures.
- `custom_lint` is not carried without a consumer.
- Toolchain upgrades are reviewed as one reproducible unit.
- A dated, owned probe prevents another analyzer incompatibility from becoming
  invisible technical debt.

### Negative

- Analysis-server plugins add analysis time and another version constraint.
- Candidate stable SDK checks can be red until upstream packages catch up.
- Committed generated output and idempotence checks make generator churn
  explicit in pull requests.

### Neutral

- This decision does not require upgrading the pinned Flutter SDK in the same
  change. It requires every upgrade to use the compatibility unit and evidence
  above.

## Alternatives considered

### Keep both lint packages removed

Rejected. The original incompatibility no longer justifies losing applicable
Riverpod correctness checks, and an undated temporary exception is technical
debt.

### Re-add both `custom_lint` and `riverpod_lint`

Rejected. Current `riverpod_lint` does not require `custom_lint`, and the
project has no custom rules that would use the additional runner.

### Always follow the newest Flutter and package releases

Rejected. Floating toolchains make generated output and release artifacts
irreproducible. Scheduled probes provide early warning while reviewed pins keep
the release path deterministic.

### Never test a newer toolchain

Rejected. It discovers analyzer and store-requirement changes only during an
urgent release upgrade.
