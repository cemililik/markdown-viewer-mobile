# ADR-0006: LaTeX math via `flutter_math_fork`

- **Status**: Accepted
- **Date**: 2026-04-12

## Context

We need to render LaTeX math expressions inline (`$...$`) and as blocks
(`$$...$$`). Options: `flutter_math`, `flutter_math_fork`, KaTeX in a
WebView, or `catex`.

## Decision

Use **`flutter_math_fork`** (≥ 0.7), the actively maintained fork of
`flutter_math`, which covers our supported subset of KaTeX.

## Consequences

### Positive

- Pure Dart, no WebView
- Integrates as a widget, supports theming
- Fast, no warmup cost

### Negative

- Not 100% KaTeX feature parity — very exotic macros may not render
- Smaller maintainer base than KaTeX itself

## Alternatives Considered

### KaTeX in WebView

Rejected: adds another WebView context and its warmup cost; duplicates
the mermaid path without clear benefits for our subset.

### `catex`

Rejected: less actively maintained than `flutter_math_fork`.
