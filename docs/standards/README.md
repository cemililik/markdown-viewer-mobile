# Standards

All contributions — human or AI — must follow the standards defined in
this directory. Standards are **binding rules**, not suggestions.
Violations must be caught by linter configuration, code review, or CI.

## Index

| Standard | Scope |
|----------|-------|
| [Coding](coding-standards.md) | Dart / Flutter code style and patterns |
| [Naming](naming-conventions.md) | File, class, variable, and symbol naming |
| [Architecture](architecture-standards.md) | Layer rules, module boundaries |
| [Error Handling](error-handling-standards.md) | Failures, exceptions, mapping |
| [Testing](testing-standards.md) | Unit, widget, integration, golden tests |
| [Code Review](code-review-standards.md) | Review checklist and etiquette |
| [Documentation](documentation-standards.md) | Doc comments, ADRs, READMEs |
| [Git Workflow](git-workflow-standards.md) | Branches, commits, PRs |
| [Security](security-standards.md) | Input handling, WebView, permissions |
| [Performance](performance-standards.md) | Budgets, profiling, regressions |
| [Accessibility](accessibility-standards.md) | Semantics, contrast, touch targets |
| [Localization](localization-standards.md) | i18n keys, plurals, RTL |
| [Observability](observability-standards.md) | Logging, crash reporting, Sentry |

## How These Integrate with AI Agents

Standards are mirrored into Claude Code as:

- [`CLAUDE.md`](../../CLAUDE.md) at the project root — always-loaded
  high-level rules
- [`.claude/skills/`](../../.claude/skills/) — invokable skills for review,
  test writing, architecture checking, and ADR drafting
- [`AGENTS.md`](../../AGENTS.md) — vendor-neutral instructions for other
  AI coding agents

AI agents **must** consult the relevant standard before producing code,
documentation, or reviews.

## Modifying a Standard

A standard change is a project-wide policy change. It requires:

1. A pull request that updates the standard document
2. A short ADR if the change is hard to reverse or affects multiple areas
3. Approval from at least one human maintainer
