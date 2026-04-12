# ADR-0004: Markdown rendering via `markdown` + `markdown_widget`

- **Status**: Accepted
- **Date**: 2026-04-12

## Context

We need a markdown pipeline that:

- Supports the full CommonMark 0.30 + GFM spec
- Exposes a pluggable AST for custom syntaxes (mermaid, math, admonitions)
- Renders into Flutter widgets with theming and selection support
- Is actively maintained

Options: `flutter_markdown`, `markdown_widget`, `gpt_markdown`, or rolling
our own.

## Decision

- **Parsing**: use the official Dart **`markdown`** package (≥ 7.2) as the
  AST layer. Register custom `BlockSyntax` / `InlineSyntax` implementations
  for mermaid, math, and admonitions.
- **Rendering**: use **`markdown_widget`** (≥ 2.3) as the widget layer with
  a custom `MarkdownGenerator` that maps our custom AST nodes to widgets.
- **Code highlighting**: use **`re_highlight`** with a theme that follows
  the active app theme.

## Consequences

### Positive

- Clean separation between parsing and rendering
- Custom block types integrate at both AST and widget levels
- `markdown_widget` supports selection, TOC, and theming out of the box
- Independent upgrades of parser and renderer

### Negative

- Two libraries to track instead of one
- `markdown_widget` has a smaller maintainer base than `flutter_markdown`

## Alternatives Considered

### `flutter_markdown`

Rejected: limited extensibility for custom block widgets; slower to adopt
new CommonMark features.

### Roll our own

Rejected: parsing CommonMark correctly is a multi-year effort we don't
want to own.
