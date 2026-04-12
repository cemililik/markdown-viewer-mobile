# Architecture Standards

These rules are enforced in code review and, where possible, by lint
rules or a custom dependency-check test.

## Layer Dependency Rules

| From ↓ To → | Domain | Application | Data | Presentation |
|-------------|:------:|:-----------:|:----:|:------------:|
| Domain      | yes    | no          | no   | no           |
| Application | yes    | yes         | no   | no           |
| Data        | yes    | no          | yes  | no           |
| Presentation| yes    | yes         | no   | yes          |

- **Presentation must not import from `data/`**
- **Domain must not import `package:flutter/*`**
- **Application must not import `package:flutter/*` except `compute`**

## Feature Boundaries

- A feature's public API is its barrel file: `features/<name>/<name>.dart`
- Cross-feature imports must go through the barrel
- Features must not import each other's private files
- Shared primitives live in `core/`

## Dependency Injection

- All dependencies are provided via Riverpod providers
- No service locators (`get_it`, etc.)
- No globals, no singletons
- No manual constructor wiring inside widgets — obtain via
  `ref.watch` / `ref.read`

## State Management

- Stateful UI uses `AsyncNotifier` / `Notifier` (riverpod_generator)
- Ephemeral widget state may use `StatefulWidget` when justified
- Never mutate Riverpod state outside a notifier method
- Use `ref.select` to narrow rebuilds

## Side Effects

- Side effects live in application-layer use cases or notifiers
- Repositories are the only side-effect entry points — all I/O passes
  through them
- Parsers, formatters, and validators are pure and live in `data/`

## Error Boundaries

- Data layer throws or returns `Failure`
- Application layer catches and translates to `AsyncValue.error`
- Presentation layer renders errors via the shared failure-to-message mapper

## Banned Patterns

- `BuildContext` captured in non-widget code
- Business logic inside `build()` methods
- Direct `Navigator.of(context)` calls — use `context.go` / `context.push`
- `setState` inside async callbacks without a `mounted` check
- `StreamBuilder` for Riverpod streams — use `ref.watch` on a `StreamProvider`
- `print` — use the `logger` package
- New top-level packages added to `pubspec.yaml` without a matching ADR
