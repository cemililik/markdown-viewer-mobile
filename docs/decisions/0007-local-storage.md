# ADR-0007: `drift` + `shared_preferences` for persistence

- **Status**: Accepted
- **Date**: 2026-04-12

## Context

We need two storage modes:

1. **Structured data** — recent files, favorites, reading progress
2. **Simple key-value** — theme, font size, last-opened file

Options for structured data: `drift`, `isar`, `sqflite`, `hive`, `realm`,
`objectbox`.

## Decision

- **Structured data**: **`drift`** (≥ 2.18) with `sqlite3_flutter_libs`
- **Key-value preferences**: **`shared_preferences`** (≥ 2.2)

Migrations are managed via drift's versioned migration API and must be
covered by tests.

## Consequences

### Positive

- drift is type-safe, codegen-driven, and well maintained
- SQLite is boring, battle-tested technology
- `shared_preferences` is the standard for simple toggles

### Negative

- Another codegen step
- Initial schema setup is more verbose than a key-value store

## Alternatives Considered

### `isar`

Rejected: maintenance status uncertain.

### `hive`

Rejected: lacks schema migrations and relational queries.

### `sqflite` (raw)

Rejected: no type safety; hand-written SQL for common cases.
