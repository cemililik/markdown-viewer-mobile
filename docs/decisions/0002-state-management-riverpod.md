# ADR-0002: Riverpod for state management

- **Status**: Accepted
- **Date**: 2026-04-12

## Context

Flutter state management options include `setState`, Provider, Riverpod,
BLoC, GetX, MobX, Redux, and Signals. We need:

- Compile-time safety for dependency injection
- Async-first primitives (`AsyncValue`)
- Testability with easy provider overrides
- Minimal boilerplate

## Decision

Use **`flutter_riverpod` ≥ 2.5** together with **`riverpod_generator`**
for code generation. Notifiers are written as `@riverpod` annotated
functions or classes, producing `Notifier` and `AsyncNotifier` providers.

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
