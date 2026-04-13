# Architecture Standards

These rules are enforced in code review and, where possible, by lint
rules or a custom dependency-check test.

## Layer Dependency Rules

The table below governs **inter-layer** imports inside this project.
Third-party Dart packages (e.g. `package:markdown`, `package:dio`,
`package:riverpod_annotation`) are *external* to the layer model and
are not constrained by these rules — only the framework / UI rules
listed beneath the table apply to them.

| From ↓ To → | Domain | Application | Data | Presentation |
|-------------|:------:|:-----------:|:----:|:------------:|
| Domain      | yes    | no          | no   | no           |
| Application | yes    | yes         | no   | no           |
| Data        | yes    | no          | yes  | no           |
| Presentation| yes    | yes         | no   | yes          |

Framework rules (apply on top of the inter-layer table):

- **Presentation must not import from `data/`.**
- **Domain must not import `package:flutter/*`** and must not import
  any UI framework (`flutter_riverpod`, `material.dart`,
  `widgets.dart`, …). Pure Dart packages such as `riverpod`,
  `meta`, `collection` are allowed.
- **Application must not import `package:flutter/*` except `compute`**
  and must not import Material / Cupertino widget libraries. Other
  third-party Dart packages are allowed because the application
  layer is where parser configuration, repository ports' generated
  bindings, and Riverpod providers live — all of which routinely
  depend on packages like `markdown`, `riverpod_annotation`, and
  `flutter_riverpod` (the project-wide DI framework chosen in
  [ADR-0002](../decisions/0002-state-management-riverpod.md)).
- **Data may import any third-party Dart or Flutter package** it
  needs to talk to the outside world (file system, HTTP, database,
  WebView, etc.).

The Dart-package allowance is what lets, for example,
`lib/features/viewer/application/markdown_extensions/math_syntax.dart`
import `package:markdown` to extend its parser with a custom block
syntax: the file is still application-layer code (it configures the
parser, it does not call into it), and `package:markdown` is a pure
Dart library, not a Flutter UI dependency.

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
