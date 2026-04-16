# AGENTS.md — Instructions for AI Coding Agents

This file is the project's vendor-neutral instruction set for AI coding
agents (Claude Code, Cursor, GitHub Copilot, Codeium, Aider, and others).
Claude Code also uses the more specific [CLAUDE.md](CLAUDE.md).

## Project Summary

Flutter application for iOS and Android that provides a rich mobile
reading experience for markdown documents — mermaid diagrams, LaTeX math,
syntax-highlighted code, tables, footnotes, admonitions, and more.

## Hard Rules

1. **All documentation is written in English.**
2. **Follow every standard in [`docs/standards/`](docs/standards/).**
   These are binding.
3. **Respect ADRs in [`docs/decisions/`](docs/decisions/).** Propose a new
   ADR before contradicting an accepted one.
4. **Feature-first layout under `lib/features/<name>/`** with layers
   `domain/`, `application/`, `data/`, `presentation/`.
5. **Layer dependency rules** (see
   [architecture-standards.md](docs/standards/architecture-standards.md)):
   - Domain imports nothing from Flutter or other layers
   - Application imports only domain
   - Data implements domain ports
   - Presentation may import application and domain, never data
6. **State management is Riverpod.** No service locators, no globals.
7. **Navigation is `go_router`.** No direct `Navigator.push` calls.
8. **Network access is limited.** All HTTP traffic must originate from
   the `repo_sync` feature, must be triggered by an explicit user action,
   and must target a host on the allow-list (`api.github.com`,
   `raw.githubusercontent.com`). The only exception is `sentry_flutter`
   which may send crash reports to `*.ingest.sentry.io` when the user
   has opted in via Settings. The mermaid WebView remains sandboxed
   with network disabled.
   See [ADR-0011](docs/decisions/0011-network-access-policy.md) and
   [security-standards.md](docs/standards/security-standards.md).
9. **No comments unless the *why* is non-obvious.**
10. **New public APIs require Dartdoc.**
11. **New behavior requires tests** to the testing standard.
12. **Never bypass hooks, linters, or CI.**
13. **Use mermaid for diagrams.** Prefer mermaid over ASCII art in
    documentation. See
    [documentation-standards.md](docs/standards/documentation-standards.md).

## Required Reading Before Your First Change

- [docs/README.md](docs/README.md)
- [docs/architecture.md](docs/architecture.md)
- [docs/standards/coding-standards.md](docs/standards/coding-standards.md)
- [docs/standards/architecture-standards.md](docs/standards/architecture-standards.md)
- [docs/standards/testing-standards.md](docs/standards/testing-standards.md)
- The ADR most relevant to your change

## Before You Submit Output

- [ ] Does the change respect layer rules?
- [ ] Are new public APIs documented?
- [ ] Are there tests for new behavior?
- [ ] Is the code free of *what*-comments?
- [ ] Does the change stay within the scope of the request?
- [ ] Does the change avoid contradicting any ADR?
