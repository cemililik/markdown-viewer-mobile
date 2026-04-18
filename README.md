# Mobile Markdown Viewer

A mobile-first Markdown viewer for **iOS** and **Android**, built with
Flutter. Designed to be the best reading experience for `.md` documents
on a phone — including Mermaid diagrams, LaTeX math, syntax-highlighted
code, tables, footnotes, and admonitions.

## Status

**v1.0.2 — released 2026-04-18.** Phases 0–5 complete. Available on
TestFlight and the Play Console production track.

v1.0 shipped after a full-application code review (128 findings across 8
streams — all P0/P1 findings closed, architecture layer refactored), a
dedicated security review (1 High + 8 Medium findings — the High and four
Medium findings resolved before tagging), and `leak_tracker` globally
enabled in the test harness. See [docs/roadmap.md](docs/roadmap.md) for
the full delivery history and post-v1 candidates.

## Features

### Rendering

- **CommonMark + GFM** — tables, task lists, strikethrough, autolinks
- **Mermaid diagrams** — 12 diagram types rendered in a sandboxed WebView
  with an LRU cache and dark/light theming
- **LaTeX math** — inline and block equations via `flutter_math_fork`
- **Syntax-highlighted code** — 100+ languages, themed to the active color
  scheme
- **Admonitions** — GitHub-style `> [!NOTE]`, `[!WARNING]`, `[!TIP]`, etc.
- **Footnotes** — rendered as tap-to-open bottom sheets

### Reading experience

- Table of contents drawer with tap-to-jump navigation
- In-document search with inline highlighting (browser find-in-page style)
- Reading comfort toolbar — font scale, reading width, line height
- Immersive scroll with auto-hide AppBar and FAB
- Light, dark, and sepia themes; AMOLED true-black planned for v1.1
- Keep-screen-on toggle
- Text selection, copy, and share
- In-document anchor links
- Reading time estimate
- PDF export with Mermaid diagrams and math preserved

### Library and sync

- Folder browser with iOS security-scoped bookmarks and Android SAF
- GitHub repository sync — one URL syncs an entire `.md` tree offline
- Optional Personal Access Token stored in the platform Keychain / Keystore
- Incremental re-sync using SHA-based change detection
- Recent documents, self-cleaning stale entries
- First-run onboarding with a pre-loaded example library

### Platform integration

- Default `.md` file handler on iOS and Android
- Adaptive splash screens and app icons (Material You on Android 12+)
- Accessibility — semantic annotations, 44 dp touch targets
- Sentry crash reporting (opt-in, consent-gated)

## Highlights

- **Offline-first** — no network required after the initial sync; the network
  is only touched on explicit user action against an allow-listed host
- **Privacy-respecting** — no accounts, no telemetry, no background traffic;
  PATs are encrypted in the OS keychain
- **Production-grade pipeline** — tag-triggered CI/CD, signed builds,
  R8 obfuscation, symbolication, `leak_tracker` in tests

## Documentation

All product, engineering, and process documentation lives under
[`docs/`](docs/). Start here:

| Audience | Start with |
|---|---|
| New contributor | [docs/README.md](docs/README.md) → [CONTRIBUTING.md](CONTRIBUTING.md) |
| Engineer | [docs/architecture.md](docs/architecture.md) → [docs/standards/](docs/standards/) |
| Product / planning | [docs/vision.md](docs/vision.md) → [docs/roadmap.md](docs/roadmap.md) |
| Decision history | [docs/decisions/](docs/decisions/) (14 ADRs) |

## Tech Stack

Flutter 3.41 · Dart 3.11 · Riverpod · go_router · Material 3 · drift ·
markdown_widget · flutter_inappwebview (Mermaid) · flutter_math_fork · dio
(repo sync). Full inventory in [docs/tech-stack.md](docs/tech-stack.md).

## Quick Start

```bash
git clone https://github.com/cemililik/markdown-viewer-mobile.git
cd markdown-viewer-mobile
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
bash tool/fetch_mermaid.sh    # downloads the pinned mermaid.min.js (not committed)
bash tool/install-hooks.sh    # installs the mandatory pre-commit hook
flutter test
flutter run
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full development workflow.

## Platform Support

| Platform | Minimum | Target |
|---|---|---|
| iOS / iPadOS | 14.0 | 17.x |
| Android | API 26 (8.0) | API 35 (15) |

HarmonyOS native support is out of scope for v1 — see
[ADR-0009](docs/decisions/0009-platform-scope.md). HarmonyOS devices
that support Android apps can install the Android build.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
Copyright © 2026 Cemil ILIK.
