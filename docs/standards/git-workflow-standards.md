# Git Workflow Standards

## Branching

- Trunk-based with short-lived branches
- Branch names: `<type>/<short-slug>` — e.g. `feat/mermaid-block`,
  `fix/toc-scroll-jitter`
- Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `ci`
- Branch off `main`, never off another feature branch
- Maximum lifetime: five working days before rebase or merge

## Commits

- Follow [Conventional Commits](https://www.conventionalcommits.org/):
  - `feat(viewer): render mermaid flowcharts`
  - `fix(toc): correct scroll offset after rotation`
  - `docs(standards): add accessibility rules`
- Imperative mood, lowercase, no trailing period
- Body explains *why*, not *what*
- Footer may include `Refs: #123` or `BREAKING CHANGE: ...`

## Pull Requests

- One PR equals one logical change
- Title mirrors the commit convention
- Description template:

```
## Summary
<1–3 sentences on what and why>

## Changes
- <bulleted list>

## Test plan
- [ ] <manual / automated checks>

## Related
- Closes #123
```

- Link related ADRs
- Screenshots or screen recordings for UI changes
- No merging a same-day PR you opened without a one-hour review window

## Review & Merge

- At least one approval required
- Squash-and-merge by default
- Rebase-and-merge for clean, well-separated commit histories
- Merge commits discouraged for feature branches
- Force-push to feature branches is allowed; never to `main`

## Protected Branches

- `main` is protected: no direct pushes, no force-push, requires CI + review

## Tags & Releases

- Semantic versioning: `vMAJOR.MINOR.PATCH`
- Tags are annotated and signed
- Release notes auto-generated from conventional commits with manual curation

## Hook Discipline

- Never use `--no-verify` to bypass hooks
- If a hook fails, fix the underlying issue
