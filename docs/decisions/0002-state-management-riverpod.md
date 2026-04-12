# ADR-0002: Riverpod for state management

- **Status**: Accepted (version pin updated by
  [ADR-0013](0013-codegen-ecosystem-alignment.md))
- **Date**: 2026-04-12

## Context

Flutter state management options include `setState`, Provider, Riverpod,
BLoC, GetX, MobX, Redux, and Signals. We need:

- Compile-time safety for dependency injection
- Async-first primitives (`AsyncValue`)
- Testability with easy provider overrides
- Minimal boilerplate

## Decision

Use **`flutter_riverpod`** together with **`riverpod_generator`** for code
generation. Notifiers and providers are written as `@riverpod` annotated
functions or classes, producing `Notifier`, `AsyncNotifier`, and plain
`Provider` outputs as appropriate. Manual `Provider((_) => ...)`
declarations are not used — the generator is the canonical provider
pattern across the whole codebase.

Concrete pinned versions live in [tech-stack.md](../tech-stack.md) and
`pubspec.yaml`. The original 2.5+ pin in this ADR was updated to the
3.x line by [ADR-0013](0013-codegen-ecosystem-alignment.md) for Flutter
3.41 compatibility.

## Consequences

### Positive

- Compile-time safe DI without coupling to `BuildContext`
- `AsyncValue` is a perfect fit for our file-loading flows
- Provider overrides give us a clean test story
- Codegen eliminates boilerplate

### Negative

- Extra build step via `build_runner`
- Learning curve for contributors new to Riverpod

## Alternatives Considered

### BLoC

Rejected: more boilerplate for the same outcomes; less ergonomic for
async-first flows; DI requires a separate container.

### Provider

Rejected: superseded by Riverpod; fewer safety guarantees.

### Signals

Rejected: promising but too young to base our foundation on.
