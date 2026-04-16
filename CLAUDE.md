# Mobile Markdown Viewer — Project Instructions for Claude Code

This is a Flutter application for iOS and Android that provides a rich
mobile reading experience for markdown documents, including mermaid
diagrams, LaTeX math, syntax-highlighted code, tables, footnotes, and
admonitions.

**You MUST read and follow the project standards before producing any
output for this project.**

## Standards — Binding Rules

These documents define binding rules for all code, documentation, and
review output. Consult the relevant document for any non-trivial task.

- [docs/standards/coding-standards.md](docs/standards/coding-standards.md)
- [docs/standards/naming-conventions.md](docs/standards/naming-conventions.md)
- [docs/standards/architecture-standards.md](docs/standards/architecture-standards.md)
- [docs/standards/error-handling-standards.md](docs/standards/error-handling-standards.md)
- [docs/standards/testing-standards.md](docs/standards/testing-standards.md)
- [docs/standards/code-review-standards.md](docs/standards/code-review-standards.md)
- [docs/standards/documentation-standards.md](docs/standards/documentation-standards.md)
- [docs/standards/git-workflow-standards.md](docs/standards/git-workflow-standards.md)
- [docs/standards/security-standards.md](docs/standards/security-standards.md)
- [docs/standards/performance-standards.md](docs/standards/performance-standards.md)
- [docs/standards/accessibility-standards.md](docs/standards/accessibility-standards.md)
- [docs/standards/localization-standards.md](docs/standards/localization-standards.md)
- [docs/standards/observability-standards.md](docs/standards/observability-standards.md)

## Architecture Summary

- Feature-first folder layout under `lib/features/<name>/`
- Clean architecture layers: domain → application → data → presentation
- Riverpod + `riverpod_generator` for state management and DI
- `go_router` for navigation
- Material 3 with dynamic color
- All documentation in **English**
- **Network access is allowed only inside the `repo_sync` feature**, only
  on explicit user action, and only against an allow-list of hosts —
  see [ADR-0011](docs/decisions/0011-network-access-policy.md). The only
  exception is `sentry_flutter` which may send crash reports to
  `*.ingest.sentry.io` when the user has opted in — see
  [ADR-0014](docs/decisions/0014-logging-and-observability.md).
- **Use mermaid diagrams** in documentation wherever they explain
  structure, flow, or state more clearly than prose

## Decision History

Architectural decisions are recorded as ADRs in
[docs/decisions/](docs/decisions/). **Do not contradict an accepted ADR**
without proposing a new ADR that supersedes it.

## AI Agent Operating Rules

1. **Consult standards before writing code.** Open the relevant standard
   document and let it constrain your output.
2. **Respect the layer dependency matrix.** Never import data from
   presentation; never import `package:flutter/*` from domain.
3. **No features, fixes, or refactors beyond the explicit ask.** Do not
   "while I'm here" cleanup.
4. **New architectural decisions require a new ADR.** Propose the ADR
   before writing code that depends on the decision.
5. **Use English for all documentation and comments.**
6. **Never add comments that explain *what* the code does.** Comment only
   when the *why* is non-obvious (invariant, workaround, perf trick).
7. **Never bypass hooks, linters, or CI.** If something fails, fix the
   underlying issue.
8. **Test to the standards.** New behavior requires tests; coverage
   floors are hard limits.
9. **Confirm before destructive actions.** Deletes, force pushes, schema
   drops, and dependency removals require explicit user approval.
10. **Surface uncertainty.** If standards, ADRs, and code disagree, stop
    and ask rather than guess.

## Available Project Skills

Invoke these via the Skill tool for project-specific operations:

- `flutter-code-review` — review a change against all standards
- `flutter-test-writing` — produce tests to the testing standard
- `flutter-architecture-check` — verify a change against layer rules
- `adr-writing` — draft a new ADR in the project format
- `standards-check` — cross-check output against all relevant standards

## When Unsure

Prefer reading an existing file in the codebase over guessing. Prefer
asking the user over inventing APIs. Prefer a small, focused change over
a sweeping one.
