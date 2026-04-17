# Mobile Markdown Viewer

A mobile-first Markdown viewer for **iOS** and **Android**, built with
Flutter. Designed to be the best mobile reading experience for `.md`
documents — including Mermaid diagrams, LaTeX math, syntax-highlighted
code, tables, footnotes, and admonitions.

## Status

🟡 **Phase 5 — Hardening & Release, final stretch.** Phases 0–4.5 are
complete. Current beta is **v0.2.2** on TestFlight and Play Console.
The app ships full markdown rendering (Mermaid, LaTeX math,
syntax-highlighted code, footnotes, admonitions), reading-comfort
toolbar, TOC drawer, in-document search with inline highlighting, text
selection, PDF export with embedded Mermaid diagrams, GitHub repository
sync, Sentry crash reporting (opt-in), and native file-open integration
on iOS and Android.

The [2026-04-16 full-application code review](docs/analysis/codereviews/codereview-report-20260416.md)
is closed on all P0 and P1 findings (34/34) and on the architecture
layer refactor (P2-1..5). See [docs/roadmap.md](docs/roadmap.md) for the
detailed delivery history and the remaining blockers for v1.0 (LICENSE,
CHANGELOG, beta bug-fix pass).

## Highlights

- **Offline-first reading** — no network required for local files
- **Bring your own docs** — sync entire `.md` trees from public GitHub
  repositories with one URL, then read offline
- **Complete rendering** — full CommonMark + GFM, plus mermaid, math,
  syntax highlighting, footnotes, admonitions
- **Mobile-first UX** — Material 3, dynamic color, dark mode, one-handed
  reading
- **Privacy-respecting** — zero telemetry, no background traffic, no accounts

## Documentation

All product, engineering, and process documentation lives under
[`docs/`](docs/). Start here:

| Audience | Start with |
|----------|-----------|
| New contributor | [docs/README.md](docs/README.md) → [CONTRIBUTING.md](CONTRIBUTING.md) |
| Engineer | [docs/architecture.md](docs/architecture.md) → [docs/standards/](docs/standards/) |
| Product / planning | [docs/vision.md](docs/vision.md) → [docs/roadmap.md](docs/roadmap.md) |
| Decision history | [docs/decisions/](docs/decisions/) (13 ADRs) |

## Tech Stack

Flutter 3.41 · Dart 3.11 · Riverpod · go_router · Material 3 · drift ·
markdown_widget · flutter_inappwebview (mermaid) · flutter_math_fork ·
dio (repo sync). Full inventory in [docs/tech-stack.md](docs/tech-stack.md).

## Quick Start

```bash
git clone https://github.com/cemililik/markdown-viewer-mobile.git
cd markdown-viewer-mobile
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
bash tool/fetch_mermaid.sh    # download pinned mermaid.min.js (not committed to git)
bash tool/install-hooks.sh    # mandatory pre-commit hook
flutter test
flutter run
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full development workflow.

## Platform Support

| Platform | Minimum | Target |
|----------|---------|--------|
| iOS / iPadOS | 14.0 | 17.x |
| Android | API 26 (8.0) | API 34 (14) |

HarmonyOS native support is out of scope for v1 — see
[ADR-0009](docs/decisions/0009-platform-scope.md). HarmonyOS devices
that support Android apps can install the Android build.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
Copyright © 2026 Cemil ILIK.
