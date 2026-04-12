# ADR-0010: Layered testing strategy

- **Status**: Accepted
- **Date**: 2026-04-12

## Context

A rendering-heavy app has three distinct risk surfaces: pure logic
(parsers, failure mapping), widget behavior (layout, interaction), and
end-to-end behavior (open file, see pixels). We need a strategy that
covers all three without making CI unbearably slow.

## Decision

Adopt a **three-tier testing strategy**:

1. **Unit tests** — exhaustive coverage of domain and application
2. **Widget + golden tests** — primary screens and critical widgets,
   per theme and locale
3. **Integration tests** — a small number of critical end-to-end scenarios
   on real devices (CI: iOS simulator + Android emulator)

Coverage floors: 95% domain, 90% application, 80% overall.

Full rules in
[../standards/testing-standards.md](../standards/testing-standards.md).

## Consequences

### Positive

- Risk-tier matches cost-tier: cheap tests are plentiful, expensive ones
  are focused
- CI stays fast on PRs; integration tests gate release builds only
- Goldens catch visual regressions in a reading-heavy UI

### Negative

- Golden tests can flake on font or engine changes — mitigated by pinning
  the Flutter version in CI

## Alternatives Considered

### Integration-heavy

Rejected: slow CI, flaky, harder to diagnose.

### Unit-only

Rejected: leaves visual and platform integration uncovered.
