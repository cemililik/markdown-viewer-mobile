# ADR-0003: go_router for navigation

- **Status**: Accepted
- **Date**: 2026-04-12

## Context

We need declarative, type-safe routing that integrates with Riverpod and
supports deep links (for share intents and file-open intents).

## Decision

Use **`go_router` ≥ 14** with typed route definitions via
`go_router_builder`. Routes are declared centrally in
`lib/app/router.dart`.

## Consequences

### Positive

- Declarative route graph
- Deep-link friendly — essential for share intents
- Works cleanly with Riverpod for redirects and guards
- Typed routes via codegen prevent route name typos

### Negative

- Requires an additional codegen step
- Transition customization is slightly more verbose than `Navigator 1.0`

## Alternatives Considered

### Navigator 2.0 raw

Rejected: too much boilerplate for common cases.

### auto_route

Rejected: duplicative with go_router; go_router is officially maintained
by the Flutter team.
