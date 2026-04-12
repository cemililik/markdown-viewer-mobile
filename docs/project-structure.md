# Project Structure

Feature-first layout with clean architecture layers inside each feature.

```
markdown_viewer/
├── android/                    # Android platform code
│   ├── app/src/main/
│   │   ├── AndroidManifest.xml # INTERNET permission lives here (ADR-0011)
│   │   └── res/values/
│   │       └── strings.xml     # app_name (launcher label)
│   ├── build.gradle.kts        # JVM 17 toolchain for all subprojects
│   ├── gradle/wrapper/         # Wrapper JAR is committed
│   ├── gradlew                 # Wrapper scripts are committed
│   └── gradlew.bat
├── ios/                        # iOS platform code
│   ├── Runner/
│   ├── Runner.xcodeproj/       # Deployment target: iOS 14.0 (no DEVELOPMENT_TEAM)
│   ├── RunnerTests/            # Native iOS tests (minimal; real tests are Dart)
│   └── Podfile                 # platform :ios, '14.0'
├── assets/
│   ├── mermaid/                # mermaid.min.js lands here (ADR-0005)
│   ├── fonts/
│   └── icons/
├── lib/
│   ├── main.dart               # Entry point
│   ├── app/                    # Composition root
│   │   ├── app.dart            # Root widget (MaterialApp.router)
│   │   ├── router.dart         # go_router configuration
│   │   └── theme.dart          # Material 3 themes
│   ├── core/                   # Cross-cutting primitives
│   │   ├── errors/
│   │   │   └── failures.dart
│   │   ├── logging/
│   │   ├── result/             # Result<T, F> type
│   │   ├── extensions/
│   │   └── widgets/            # Shared widgets (loaders, empty states)
│   ├── features/
│   │   ├── viewer/
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   └── document.dart
│   │   │   │   └── repositories/
│   │   │   │       └── document_repository.dart
│   │   │   ├── application/
│   │   │   │   ├── viewer_notifier.dart
│   │   │   │   └── open_document_use_case.dart
│   │   │   ├── data/
│   │   │   │   ├── document_repository_impl.dart
│   │   │   │   ├── parsers/
│   │   │   │   │   ├── markdown_parser.dart
│   │   │   │   │   ├── mermaid_syntax.dart
│   │   │   │   │   └── math_syntax.dart
│   │   │   │   └── rendering/
│   │   │   │       ├── mermaid_web_view.dart
│   │   │   │       └── code_highlighter.dart
│   │   │   ├── presentation/
│   │   │   │   ├── screens/
│   │   │   │   │   └── viewer_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── markdown_view.dart
│   │   │   │       ├── toc_drawer.dart
│   │   │   │       └── mermaid_block.dart
│   │   │   └── viewer.dart     # Public barrel
│   │   ├── library/
│   │   ├── settings/
│   │   ├── search/
│   │   ├── share/
│   │   └── repo_sync/
│   │       ├── domain/
│   │       │   ├── entities/
│   │       │   │   ├── repo_locator.dart
│   │       │   │   ├── remote_file.dart
│   │       │   │   └── synced_repo.dart
│   │       │   └── repositories/
│   │       │       └── repo_sync_repository.dart
│   │       ├── application/
│   │       │   ├── repo_sync_notifier.dart
│   │       │   └── start_sync_use_case.dart
│   │       ├── data/
│   │       │   ├── repo_sync_repository_impl.dart
│   │       │   ├── http/
│   │       │   │   └── sync_http_client.dart       # the only HTTP client
│   │       │   ├── providers/
│   │       │   │   ├── repo_sync_provider.dart     # interface
│   │       │   │   └── github_sync_provider.dart
│   │       │   ├── parsers/
│   │       │   │   └── github_url_parser.dart
│   │       │   └── storage/
│   │       │       ├── synced_repos_dao.dart
│   │       │       └── mirror_writer.dart
│   │       ├── presentation/
│   │       │   ├── screens/
│   │       │   │   └── repo_sync_screen.dart
│   │       │   └── widgets/
│   │       │       ├── url_input.dart
│   │       │       └── sync_progress.dart
│   │       └── repo_sync.dart      # Public barrel
│   └── l10n/
│       ├── app_en.arb          # ARB source of truth
│       ├── app_tr.arb
│       └── generated/          # flutter gen-l10n output (committed)
│           ├── app_localizations.dart
│           ├── app_localizations_en.dart
│           └── app_localizations_tr.dart
├── test/
│   ├── unit/
│   ├── widget/
│   ├── golden/
│   └── fixtures/
├── integration_test/
├── docs/                       # This directory
│   ├── standards/
│   ├── decisions/
│   └── how-to/                 # Task-oriented guides (e.g. add-a-language.md)
├── tool/
│   ├── install-hooks.sh        # Installs the pre-commit hook via core.hooksPath
│   └── git-hooks/
│       └── pre-commit          # Format + analyze + ARB parity + partial-stage guard
├── .github/workflows/          # CI (lint, test, android/ios debug builds)
├── .claude/                    # Claude Code skills and rules
│   └── skills/
├── CLAUDE.md                   # Claude Code project instructions
├── AGENTS.md                   # Generic AI agent instructions
├── CONTRIBUTING.md             # Contributor guide
├── analysis_options.yaml
├── l10n.yaml                   # flutter gen-l10n configuration
├── pubspec.yaml
├── pubspec.lock                # Committed so Flutter CLI has a deterministic resolve
└── README.md
```

## Rules

- A feature folder **must** contain at minimum `domain/` and `presentation/`
- Files are named in `snake_case.dart`
- The public API of a feature is re-exported from
  `features/<name>/<name>.dart` (the barrel)
- Cross-feature imports must go through the barrel — no reaching into a
  feature's internals
- Generated files (`*.g.dart`, `*.freezed.dart`) are committed to the repo
- Tests mirror the source path under `test/`
