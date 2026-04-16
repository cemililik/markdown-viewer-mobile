# Technology Stack

All version choices are documented as ADRs in [decisions/](decisions/).
This file is the canonical summary.

## Platform Targets

| Platform | Minimum | Target | Notes |
|----------|---------|--------|-------|
| iOS      | 14.0    | 26     | iPhone + iPad (Xcode 26 SDK pinned in CI per ITMS-90725) |
| Android  | API 26 (8.0) | API 35 (15) | Phones + tablets |

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

All version constraints below are **synchronized with
[`pubspec.yaml`](../pubspec.yaml)**. When bumping any package — even
a patch bump — update this table in the same PR; when bumping a major
version, also update the corresponding ADR. Drift between this table
and `pubspec.yaml` is a documentation defect.

| Concern | Package | Version | ADR |
|---------|---------|---------|-----|
| State management | `flutter_riverpod` + `riverpod_annotation` | ^3.2.1 / ^4.0.2 | [0002](decisions/0002-state-management-riverpod.md), [0013](decisions/0013-codegen-ecosystem-alignment.md) |
| Navigation | `go_router` | ^14.6.2 | [0003](decisions/0003-navigation-go-router.md) |
| Markdown AST | `markdown` | ^7.2.2 | [0004](decisions/0004-markdown-rendering.md) |
| Markdown widget | `markdown_widget` | ^2.3.2+8 | [0004](decisions/0004-markdown-rendering.md) |
| Code highlighting | `re_highlight` + `flutter_highlighting` | latest | [0004](decisions/0004-markdown-rendering.md) |
| Mermaid | `flutter_inappwebview` + bundled `mermaid.min.js` | ^6.1.5 | [0005](decisions/0005-mermaid-rendering.md) |
| SVG rendering | `flutter_svg` | ^2.0.16 | — |
| Math | `flutter_math_fork` | ^0.7.3 | [0006](decisions/0006-math-rendering.md) |
| Local DB | `drift` + `sqlite3_flutter_libs` | ^2.21.0 / ^0.5.24 | [0007](decisions/0007-local-storage.md) |
| Key-value prefs | `shared_preferences` | ^2.3.3 | [0007](decisions/0007-local-storage.md) |
| File picking | `file_picker` | ^8.1.4 | — |
| Share intent | `receive_sharing_intent` | ^1.8.1 | — |
| Theming | Material 3 + `dynamic_color` | ^1.7.0 | [0008](decisions/0008-theming-material3.md) |
| Localization | `flutter_localizations` + `intl` | pinned by SDK / ^0.20.2 | — |
| Immutable models | `freezed_annotation` + `json_annotation` | ^3.1.0 / ^4.9.0 | [0013](decisions/0013-codegen-ecosystem-alignment.md) |
| Logging | `logger` | ^2.5.0 | — |
| HTTP client (repo sync) | `dio` | ^5.7.0 | [0012](decisions/0012-document-sync-architecture.md) |
| Secure token storage | `flutter_secure_storage` | ^9.2.2 | [0012](decisions/0012-document-sync-architecture.md) |
| Path utilities | `path` | ^1.9.0 | — |
| Crypto (sha256 cache keys) | `crypto` | ^3.0.6 | — |
| Crash reporting | `sentry_flutter` + `sentry_dio` | ^9.0.0 / ^9.0.0 | [0014](decisions/0014-logging-and-observability.md) |
| PDF export | `pdf` + `printing` | ^3.12.0 / ^5.14.3 | — |
| Share sheet | `share_plus` | ^12.0.2 | — |
| External link launch | `url_launcher` | ^6.3.2 | — |
| Path provider (app dirs) | `path_provider` | ^2.1.5 | [0007](decisions/0007-local-storage.md) |
| Keep-screen-on | `wakelock_plus` | ^1.2.11 | — |
| Splash screen generation | `flutter_native_splash` (dev only) | ^2.4.3 | — |
| App icon generation | `flutter_launcher_icons` (dev only) | ^0.14.3 | — |

## Tooling

| Concern | Choice | Version |
|---------|--------|---------|
| Linter | `flutter_lints` with project-specific rules | ^5.0.0 |
| Formatter | `dart format` (80-column default) | bundled |
| Codegen | `build_runner` (riverpod_generator, freezed, drift_dev, json_serializable, go_router_builder) | ^2.13.1 |
| Custom Riverpod lints | `custom_lint` + `riverpod_lint` | **removed** (see [ADR-0013](decisions/0013-codegen-ecosystem-alignment.md)) |
| Unit / widget tests | `flutter_test` | SDK |
| Mocking | `mocktail` | ^1.0.4 |
| Golden tests | `alchemist` | ^0.12.1 |
| Integration tests | `integration_test` | SDK |
| CI | GitHub Actions | actions pinned to SHAs |
| Versioning | Semantic versioning, derived from git tags | — |

`custom_lint` and `riverpod_lint` are intentionally **not** in
`pubspec.yaml` right now because of an upstream analyzer version split
between the two. See [ADR-0013](decisions/0013-codegen-ecosystem-alignment.md)
for the details and the conditions for re-introducing them.
