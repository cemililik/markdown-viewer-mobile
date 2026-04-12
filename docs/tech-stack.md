# Technology Stack

All version choices are documented as ADRs in [decisions/](decisions/).
This file is the canonical summary.

## Platform Targets

| Platform | Minimum | Target | Notes |
|----------|---------|--------|-------|
| iOS      | 14.0    | 17.x   | iPhone + iPad |
| Android  | API 26 (8.0) | API 34 (14) | Phones + tablets |

HarmonyOS native support is **out of scope for v1** — see
[ADR-0009](decisions/0009-platform-scope.md).

## Language & Framework

| Component | Choice | Version |
|-----------|--------|---------|
| Language | Dart | bundled with Flutter 3.41 (≥ 3.7) |
| Framework | Flutter | ≥ 3.41 (stable channel) |
| SDK constraint | `sdk: ">=3.7.0 <4.0.0"` | |
| Flutter constraint | `flutter: ">=3.41.0"` | |

## Core Libraries

| Concern | Package | Version | ADR |
|---------|---------|---------|-----|
| State management | `flutter_riverpod` + `riverpod_generator` | ^2.5 | [0002](decisions/0002-state-management-riverpod.md) |
| Navigation | `go_router` + `go_router_builder` | ^14.0 | [0003](decisions/0003-navigation-go-router.md) |
| Markdown AST | `markdown` | ^7.2 | [0004](decisions/0004-markdown-rendering.md) |
| Markdown widget | `markdown_widget` | ^2.3 | [0004](decisions/0004-markdown-rendering.md) |
| Code highlighting | `re_highlight` + `flutter_highlighting` | latest | [0004](decisions/0004-markdown-rendering.md) |
| Mermaid | `flutter_inappwebview` + bundled `mermaid.min.js` | ^6.0 | [0005](decisions/0005-mermaid-rendering.md) |
| SVG rendering | `flutter_svg` | ^2.0 | — |
| Math | `flutter_math_fork` | ^0.7 | [0006](decisions/0006-math-rendering.md) |
| Local DB | `drift` + `sqlite3_flutter_libs` | ^2.18 | [0007](decisions/0007-local-storage.md) |
| Key-value prefs | `shared_preferences` | ^2.2 | [0007](decisions/0007-local-storage.md) |
| File picking | `file_picker` | ^8.0 | — |
| Share intent | `receive_sharing_intent` | ^1.8 | — |
| Theming | Material 3 + `dynamic_color` | ^1.7 | [0008](decisions/0008-theming-material3.md) |
| Localization | `flutter_localizations` + `intl` | — | — |
| Immutable models | `freezed` + `json_serializable` | ^2.5 | — |
| Logging | `logger` | ^2.4 | — |
| HTTP client (repo sync) | `dio` | ^5.4 | [0012](decisions/0012-document-sync-architecture.md) |
| Secure token storage | `flutter_secure_storage` | ^9.2 | [0012](decisions/0012-document-sync-architecture.md) |
| Path utilities | `path` | ^1.9 | — |
| Crypto (sha256 cache keys) | `crypto` | ^3.0 | — |

## Tooling

| Concern | Choice |
|---------|--------|
| Linter | `flutter_lints` with project-specific rules |
| Formatter | `dart format` (80-column default) |
| Codegen | `build_runner` (riverpod, freezed, drift, json_serializable, go_router) |
| Unit / widget tests | `flutter_test` |
| Mocking | `mocktail` |
| Golden tests | `alchemist` or `golden_toolkit` |
| Integration tests | `integration_test` |
| CI | GitHub Actions |
| Versioning | Semantic versioning, derived from git tags |
