---
name: flutter-architecture-check
description: Verify that a Flutter change respects the project's layer dependency rules and feature-module boundaries. Use before merging or after generating code that touches multiple layers or features.
---

# Flutter Architecture Check Skill

Verify a change against `docs/standards/architecture-standards.md` and
`docs/architecture.md`.

## Checks

### Layer Dependency Matrix

Apply the matrix from `architecture-standards.md`:

- Presentation → Data: forbidden
- Domain → anything else: forbidden
- Application → Flutter (except `compute`): forbidden
- Data → Presentation: forbidden

For each file in the change, list its layer and list its imports. Flag
any violation.

### Feature Boundaries

- Cross-feature imports must go through the feature barrel file
- No feature directly imports another feature's internals

### Banned Patterns

- `print` — must be `logger`
- `Navigator.of(context).push` — must be `context.go` / `context.push`
- Service locators (`get_it`, etc.) — banned
- Global singletons — banned
- `BuildContext` captured in non-widget classes — banned

### Dependencies

- New packages in `pubspec.yaml` without a matching ADR are a blocker
- Removed packages in `pubspec.yaml` without justification are a blocker

## Output Format

```
## Layer Analysis
<file> — <layer> — <dependency verdict>

## Violations
- <file:line> — <rule> — <how to fix>

## Clean
<files with no violations>
```

## When a Violation Is Found

- Cite the exact rule from `architecture-standards.md`
- Suggest the minimal fix
- Do not rewrite the whole file
