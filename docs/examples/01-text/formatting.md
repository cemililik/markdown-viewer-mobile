# Text formatting

Every inline mark the CommonMark + GFM spec defines, as the viewer
renders them.

## Emphasis

- **Bold** with `**asterisks**` or `__underscores__`.
- *Italic* with `*asterisks*` or `_underscores_`.
- ***Bold italic*** with `***three***`.
- ~~Strikethrough~~ with `~~two tildes~~` (GFM).
- `Inline code` with backticks.
- ==Highlight== and similar non-standard marks are **not** rendered —
  they show as plain text.

Nesting works as the spec prescribes: **bold with *italic inside***,
*italic with `code inside`*, ~~strike with **bold inside**~~.

## Inline code vs. prose

A path like `lib/features/viewer/presentation/screens/viewer_screen.dart`
stays monospaced and does not wrap mid-segment. Underscores inside
code survive verbatim — `snake_case_identifier` is not parsed as
italic because the tokens are inside backticks.

Outside of code, the viewer still respects word boundaries around
underscores so `snake_case_names` in prose keep their underscores and
are not italicised.

## Links

- Inline: [MarkdownViewer](https://github.com/cemililik/markdown-viewer-mobile)
- Autolink: <https://github.com/cemililik/markdown-viewer-mobile>
- Reference-style: see the [project README][readme]
- Email autolink: <hello@example.com>
- Cross-file (resolves to a sibling folder): [anchors basic](../03-navigation/anchors-basic.md)
- In-doc: jump to [horizontal rules](#horizontal-rules)

[readme]: https://github.com/cemililik/markdown-viewer-mobile

## Line breaks and paragraphs

A single newline stays inside the current paragraph, so
this line
and this line
render as one paragraph with soft wraps.

A blank line ends the paragraph.

Two trailing spaces on a line  
force a hard break without ending the paragraph.

## Escapes

Backslashes escape otherwise-meaningful characters: \*literal
asterisks\*, \_literal underscores\_, \`literal backticks\`,
\[literal brackets\]. The escape itself is consumed and only the
target character renders.

## Horizontal rules

Any of the three syntaxes produces the same rule:

---

***

___

## Unicode content

The viewer is UTF-8 throughout. Turkish (`Türkçe başlık`), CJK
(`日本語の見出し`), Arabic (`عربى`), and Emoji (😀 ✨ 🧑‍💻) all
round-trip correctly through the parser, slug generator, and
render path.

## Things the viewer deliberately does **not** render

- Raw HTML. `<div>` or `<span style="…">` survives as plain text
  because `markdown_widget` — the rendering engine — does not
  render raw HTML blocks and ships with no HTML-tag extensions
  that would interpret them. (The parser's `encodeHtml` flag is a
  separate concern: it controls whether inline HTML-entity
  sequences like `<` are encoded as `&lt;` in the AST; it does
  not determine whether raw HTML blocks are rendered.)
- YAML frontmatter. A `---` block at the top of the file is treated
  as a thematic break, not as metadata — the viewer is a reader,
  not a build system.
- Custom block syntaxes outside of Mermaid, math, and admonitions.
  Those three are explicitly supported; everything else falls
  through to CommonMark defaults.
