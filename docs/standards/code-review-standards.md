# Code Review Standards

## Philosophy

Code review is a collaborative quality gate, not a gatekeeping ritual.
Reviewers and authors share responsibility for the outcome.

## Reviewer Checklist

### Correctness

- [ ] Does the change do what the PR description says?
- [ ] Are edge cases handled (empty input, null, large input, unicode)?
- [ ] Is error handling consistent with
      [error-handling-standards.md](error-handling-standards.md)?
- [ ] Are there any unhandled futures?

### Architecture

- [ ] Does the change respect the layer dependency rules?
- [ ] Are new dependencies justified, in the right layer, and ADR-backed?
- [ ] Is the public API minimal?
- [ ] Does the feature folder structure follow the convention?

### Readability

- [ ] Can a new contributor understand this in a single pass?
- [ ] Are names self-explanatory?
- [ ] Are there comments that explain *what* instead of *why*?
- [ ] Are there any commented-out code blocks?

### Testing

- [ ] Are tests present for new behavior?
- [ ] Do tests cover happy path **and** failure modes?
- [ ] Do tests follow the naming convention?
- [ ] Does overall coverage stay at or above the floor?

### Performance

- [ ] Any obvious allocations inside `build()`?
- [ ] Any new synchronous I/O on the UI isolate?
- [ ] Does the change impact any performance budget?

### Security

- [ ] Any new WebView usage? Is it sandboxed per security standards?
- [ ] Any new file system access? Does it respect scoped storage?
- [ ] Any new network calls? (Should be zero for v1.)

### Docs

- [ ] Are public APIs documented?
- [ ] Are new architectural decisions captured as an ADR?
- [ ] Is `CHANGELOG.md` updated if user-visible?

## Author Checklist Before Requesting Review

- [ ] Self-review the diff as if you were the reviewer
- [ ] PR description explains *why*, not just *what*
- [ ] Tests pass locally
- [ ] `dart analyze` is clean
- [ ] `dart format .` applied
- [ ] No unrelated changes sneak in

## Review Etiquette

- Comment on code, not people
- Distinguish blocking issues from suggestions: prefix with `nit:`,
  `question:`, or `blocker:`
- Prefer questions over commands when intent is unclear
- Approve with outstanding nits only when the author is trusted to address them
- Resist "while you're here, also fix X"

## Size Limits

| Size | Guidance |
|------|----------|
| < 200 LOC | Normal — aim for same-day review |
| 200–500 LOC | Acceptable with clear scoping |
| 500–1000 LOC | Author should justify in description |
| > 1000 LOC | Must be split unless mechanical refactor |

## AI-Generated Changes

AI-authored or AI-assisted PRs are subject to the **same** standards.
The human submitter is accountable for the final code. Reviewers must
apply extra scrutiny to:

- Invented APIs or package names
- Patterns from other ecosystems (React, iOS native) imported mechanically
- Overly defensive code (unnecessary null checks, try/catch without purpose)
- Comments that explain *what* the code does
- Out-of-scope changes ("while I was there")
