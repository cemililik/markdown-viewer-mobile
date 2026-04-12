# Contributing to Mobile Markdown Viewer

Thanks for your interest in improving the project. This document tells
you everything you need to know to contribute effectively, whether you
are a human contributor or working with an AI coding agent.

## Before You Start

1. Read [docs/README.md](docs/README.md) to understand the project
2. Read [docs/architecture.md](docs/architecture.md) for the big picture
3. Read [docs/standards/README.md](docs/standards/README.md) — every
   standard listed there is **binding**
4. Skim [docs/decisions/README.md](docs/decisions/README.md) for the
   architectural decisions that already exist

## Ways to Contribute

| Contribution | Where to start |
|--------------|----------------|
| Bug report | Open an issue with steps to reproduce |
| Feature proposal | Open an issue describing the use case and constraints |
| Documentation | Edit files under `docs/` and follow the docs standard |
| Code | Pick an issue labeled `good-first-issue` or `help-wanted` |
| Localization | Add or update keys in `lib/l10n/` |

## Reporting Issues

Use the issue templates. A good bug report includes:

- A short title that names the symptom
- Steps to reproduce
- What you expected to happen
- What actually happened
- Device, OS version, app version
- A minimal `.md` sample if rendering is involved

For security issues, do **not** open a public issue. Email the maintainers
privately so we can coordinate a fix and a responsible disclosure.

## Development Setup

### Prerequisites

- Flutter `≥ 3.41` on the stable channel
- Dart bundled with Flutter 3.41 (`≥ 3.7`)
- Xcode `≥ 15` (for iOS)
- Android Studio / Android SDK with API 34
- Git, with commit signing recommended

### First-time setup

```bash
git clone <repo-url>
cd markdown_viewer
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
bash tool/install-hooks.sh    # installs the pre-commit hook
flutter test
```

The pre-commit hook runs `dart format`, `flutter analyze`, and an ARB
key-parity check on your staged changes. It is mandatory — do not bypass
it with `--no-verify` (see
[git-workflow-standards.md](docs/standards/git-workflow-standards.md)).

### Running the app

```bash
flutter run                # default device
flutter run -d ios         # iOS simulator
flutter run -d android     # Android emulator
```

### Code generation

`riverpod_generator`, `freezed`, `drift`, `json_serializable`, and
`go_router_builder` rely on `build_runner`:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Branching, Commits, and PRs

Follow [git-workflow-standards.md](docs/standards/git-workflow-standards.md).
Highlights:

- Branch naming: `<type>/<short-slug>` — e.g. `feat/repo-sync`
- Conventional Commits: `feat(viewer): render mermaid flowcharts`
- One PR equals one logical change
- PR descriptions explain *why*, not just *what*
- Link related issues and ADRs

## Testing Requirements

See [testing-standards.md](docs/standards/testing-standards.md). Highlights:

- New behavior requires tests
- Coverage floors are hard limits: 95% domain, 90% application, 80% overall
- Don't test generated code or private implementation details
- Run `flutter test --coverage` before requesting review

## Documentation Requirements

See [documentation-standards.md](docs/standards/documentation-standards.md).
Highlights:

- All documentation is written in **English**
- New public APIs in `core/` and feature barrels need Dartdoc
- New architectural decisions need an ADR (use the
  [adr-writing](.claude/skills/adr-writing/SKILL.md) skill if you have
  Claude Code)
- Use mermaid diagrams for structure, flow, and state — prefer mermaid
  over ASCII art

## Code Review

See [code-review-standards.md](docs/standards/code-review-standards.md).
Highlights:

- Comment on code, not people
- Prefix non-blocking comments with `nit:` or `question:`
- Reviewers verify standards compliance before approving
- Authors self-review the diff before requesting review

## AI-Assisted Contributions

AI coding agents are welcome to contribute. The same standards apply, and
the **human submitter is accountable** for the final code. Reviewers
apply extra scrutiny to:

- Invented APIs or package names
- Patterns from other ecosystems imported mechanically
- Overly defensive code (unnecessary null checks, try/catch without purpose)
- Comments that explain *what* the code does
- Out-of-scope changes ("while I was there")

If you use Claude Code, the project's [`CLAUDE.md`](CLAUDE.md) and
[`.claude/skills/`](.claude/skills/) skills are pre-configured to enforce
the standards. For other agents, see [`AGENTS.md`](AGENTS.md).

## Releases

Releases are cut from `main` using semver tags (`vMAJOR.MINOR.PATCH`).
Changelog entries follow Keep a Changelog format. Maintainers handle the
release pipeline.

## Communication

- **Issues** — bugs, feature proposals, design discussions
- **Pull requests** — code, doc, and standards changes
- **Discussions** — open questions, ideas not yet ready for an issue

## License

By contributing you agree that your contributions will be licensed under
the project's open-source license (see `LICENSE` in the repository root).
