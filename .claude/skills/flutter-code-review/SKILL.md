---
name: flutter-code-review
description: Review a Flutter code change against the project's binding standards — coding, architecture, error handling, testing, performance, security, and accessibility. Use when the user asks for a review, audit, critique, or sanity check of code changes in this project.
---

# Flutter Code Review Skill

Review a code change against the binding standards in
`docs/standards/`. Produce a structured, specific, actionable review.

## Inputs

- A diff, a file, a PR description, or a code block the user has asked
  you to review
- If the scope is unclear, ask the user which files or which PR

## Process

1. **Read the relevant standards** before the code. At minimum:
   - `docs/standards/coding-standards.md`
   - `docs/standards/architecture-standards.md`
   - `docs/standards/error-handling-standards.md`
   - `docs/standards/testing-standards.md`
   - `docs/standards/code-review-standards.md`
2. Skim the change to understand the *intent*
3. Walk the change file by file applying the reviewer checklist from
   `docs/standards/code-review-standards.md`
4. Cross-reference ADRs — does the change contradict any accepted ADR?
5. Group findings by severity

## Output Format

```
## Summary
<2–3 sentences: what the change does and overall assessment>

## Blockers
- <file:line> — <issue> — <which standard rule>

## Suggestions
- <file:line> — <suggestion>

## Nits
- <file:line> — <nit>

## Tests
<assessment of test coverage vs testing-standards.md>

## Standards Referenced
- <list of standards docs consulted>
```

## Severity Rules

- **Blocker**: violates a hard rule in a standard or an ADR, or a
  correctness bug. Must be fixed before merge.
- **Suggestion**: a real improvement that is not a rule violation.
- **Nit**: style or preference; the author may ignore.

## Things to Actively Watch For

- Layer boundary violations (presentation → data, domain → Flutter)
- `print` instead of `logger`
- Missing `mounted` checks after `await` in widgets
- Unawaited futures
- Hardcoded user-facing strings (should be localized)
- `setState` in async callbacks
- Direct `Navigator` calls instead of `context.go`
- New WebView code without sandbox configuration
- Comments that explain *what* instead of *why*
- Missing tests for new behavior
- Coverage regression
- New dependencies without an ADR

## Do Not

- Rewrite the code for the author
- Suggest unrelated refactors
- Bikeshed formatting the linter already handles
- Approve a change you have not actually read
