# Coding Standards

## Language

- Use Dart 3.7+ language features: records, patterns, sealed classes
- Prefer `sealed class` over `abstract class` + manual sum-types
- Prefer records for transient tuples; `freezed` for durable data
- Use pattern matching (`switch` expression) for exhaustive dispatch

## Types

- **No implicit `dynamic`** — enabled via `strict-raw-types: true`
- **No implicit casts** — enabled via `strict-casts: true`
- Prefer `final` for locals; use `const` wherever the analyzer allows
- Use value-typed IDs (e.g., `DocumentId`) rather than raw `String` / `int`
- Represent optional fields with nullable types, never with sentinel values

## Immutability

- All domain models are immutable via `freezed`
- State objects for Riverpod notifiers are immutable
- Prefer `copyWith` over mutation; never mutate objects shared across frames

## Functions

- Functions do one thing. If a function exceeds 30 lines, reconsider it.
- Prefer named parameters for public APIs with three or more parameters
- Required parameters come before optional named parameters
- Return types are always explicit on public APIs

## Async

- Use `async` / `await`, not raw `.then()`
- Every `Future` must be awaited, ignored via `unawaited()`, or returned
- Never block the UI isolate on CPU-heavy work; use `compute()`
- Cancel long-running operations on widget disposal via `ref.onDispose`

## Widgets

- Prefer `StatelessWidget` + Riverpod over `StatefulWidget`
- Extract widgets above 100 lines into their own files
- Use `const` constructors wherever possible
- No business logic in `build()` — composition only

## Imports

- Import order: `dart:*`, `package:flutter/*`, `package:*`, then local
- No wildcard imports across feature boundaries
- Use `package:` imports, not relative, for cross-folder imports

## Comments

- Default is **no comments** — names and types should communicate intent
- Only comment the *why* when it is non-obvious: an invariant, a workaround,
  a performance trick, or a spec reference
- Do not write `TODO` without an associated issue number
- Dartdoc (`///`) is required on public APIs of `core/` and any exported
  feature barrel file

## Analyzer Configuration

`analysis_options.yaml` must include at least:

```yaml
include: package:flutter_lints/flutter.yaml
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore
linter:
  rules:
    - always_declare_return_types
    - always_use_package_imports
    - avoid_dynamic_calls
    - avoid_print
    - avoid_returning_null_for_future
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_locals
    - require_trailing_commas
    - sort_constructors_first
    - unawaited_futures
    - use_build_context_synchronously
    - use_super_parameters
```

## Formatting

- `dart format` with default 80-column width, no overrides
- Trailing commas required on multi-line collections and parameter lists
- One blank line between top-level declarations
