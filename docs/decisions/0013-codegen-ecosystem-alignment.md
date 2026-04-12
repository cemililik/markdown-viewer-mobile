# ADR-0013: Align codegen ecosystem on Riverpod 3.x and freezed 3.x

- **Status**: Accepted
- **Date**: 2026-04-12
- **Updates**: [ADR-0002](0002-state-management-riverpod.md) (Riverpod
  version bump)

## Context

[ADR-0002](0002-state-management-riverpod.md) pinned Riverpod to the 2.x
line, and the initial `pubspec.yaml` also pinned `freezed` to 2.x and
`go_router_builder` to 2.x. These versions transitively pull in
`analyzer_plugin 0.12.0`, which was compiled against the `analyzer 6.x`
line.

Flutter 3.41 bundles `analyzer 7.6.0`. When we attempted
`dart run build_runner build` during the first PR review cycle it
failed with several compilation errors inside
`analyzer_plugin/change_builder_dart.dart` (`TopLevelDeclarations`,
`LibraryElement2`, `publiclyExporting2`), because the plugin was
referencing APIs that no longer exist in the newer analyzer. The
failure blocks **every** generator — `riverpod_generator`, `freezed`,
`json_serializable`, `drift_dev`, and `go_router_builder` all share the
same `build_runner` entrypoint and cannot run when its build script
fails to compile.

At the same time, the PR reviewer pointed out that our
`lib/app/router.dart` was using a manual `Provider((_) => ...)` instead
of the `@riverpod` annotated function that the project's declared
`riverpod_generator` dependency is supposed to enable. We cannot adopt
the `@riverpod` pattern without a working build_runner.

We therefore need to either:

1. Upgrade the codegen ecosystem to versions that support the newer
   analyzer, or
2. Downgrade Flutter (undesirable — Flutter 3.41 is the documented
   target in [tech-stack.md](../tech-stack.md)).

## Decision

Bump the codegen-critical dependencies to the first releases on the
major version that target the analyzer bundled with Flutter 3.41:

| Package | Before | After |
|---------|--------|-------|
| `flutter_riverpod` | ^2.6.1 | ^3.2.1 |
| `riverpod_annotation` | ^2.6.1 | ^4.0.2 |
| `riverpod_generator` | ^2.6.3 | ^4.0.3 |
| `freezed_annotation` | ^2.4.4 | ^3.1.0 |
| `freezed` | ^2.5.7 | ^3.2.5 |
| `go_router_builder` | ^2.7.5 | ^4.2.1 |
| `build_runner` | ^2.4.13 | ^2.13.1 |

`intl` remains pinned to `^0.20.2` (set by `flutter_localizations`), and
`go_router` remains on the 14.x line because the reviewer-flagged issue
was with the **builder**, not the runtime router itself.

`custom_lint` and `riverpod_lint` are **removed** from the project
entirely for now. The latest versions pin incompatible analyzer ranges:

- `custom_lint 0.8.x` still depends on `analyzer ^8.0.0`
- `riverpod_lint 3.1.1+` depends on `analyzer ^9.0.0`

With the core codegen pulling analyzer 9, there is no version pair of
`custom_lint` + `riverpod_lint` that we can install together with
`freezed 3.x`. The loss is acceptable because the project-wide
`analysis_options.yaml` already enforces the core rules that matter,
and the Riverpod-specific lints were a polish, not a correctness gate.

## Consequences

### Positive

- `dart run build_runner build` works on Flutter 3.41 — `router.dart`
  and every future `@riverpod` / `@freezed` / `@DriftDatabase` class can
  now be codegen-driven.
- The project is now aligned with the Riverpod 3.x line, which is where
  all upstream improvements and security fixes land.
- `freezed 3.x` supports the pattern-matching features of Dart 3.x
  directly, which will simplify sealed-class models in the domain layer.

### Negative

- **Riverpod 3.x has breaking API changes** from 2.x. The shell app only
  uses `ref.watch(routerProvider)` and a single `@Riverpod` function, so
  the migration cost for the current code was trivial — but future
  contributors writing Notifiers need to reference the Riverpod 3.x
  docs, not older 2.x snippets.
- **`custom_lint` and `riverpod_lint` are temporarily unavailable.** The
  project loses Riverpod-specific lint suggestions (e.g. missing
  `autoDispose`, provider naming) until upstream realigns on a single
  analyzer line. `flutter analyze` still catches every rule in
  [coding-standards.md](../standards/coding-standards.md).
- More ongoing churn: every time Flutter bumps its bundled analyzer, we
  will need to revisit this matrix.

## Alternatives Considered

### Downgrade Flutter to 3.40 or earlier

Rejected: Flutter 3.41 is the documented target
([tech-stack.md](../tech-stack.md), [roadmap.md](../roadmap.md),
[CONTRIBUTING.md](../../CONTRIBUTING.md), [CI](../../.github/workflows/ci.yml)).
Downgrading would mean accepting a stale SDK for the entire project
lifecycle just to keep `custom_lint` happy.

### Stay on Riverpod 2.x and drop `@riverpod` codegen

Rejected: we would have to remove `riverpod_generator`, `freezed`, and
every other codegen dependency from the project, which defeats the
point of having `riverpod_generator` in the tech stack at all. The PR
reviewer's concern was explicit — we should use the annotations because
we've already committed to the codegen.

### Keep `custom_lint` and revert `freezed` / `riverpod` to 2.x

Rejected: this is the state that was already failing. We cannot keep
`custom_lint 0.7.x` working on Flutter 3.41 because its transitive
`analyzer_plugin` dependency does not compile.

## Revisit Criteria

Re-add `custom_lint` and `riverpod_lint` when either:

1. A single version of `custom_lint` supports both `analyzer 8.x` and
   `analyzer 9.x` and the community has settled on it, **or**
2. `riverpod_lint` ships a release that targets `analyzer 8.x` again, **or**
3. The project explicitly decides the developer-experience gain is
   worth pinning to an older analyzer range (which would require
   downgrading other dependencies in turn).

Until then, the project's `analysis_options.yaml` and the standards in
`docs/standards/` are the enforcement layer.
