# Footnotes

GFM footnotes. Tap a `^ref` in the text to open a bottom sheet with
the footnote body; tap the sheet background to dismiss.

## Single footnote

The MarkdownViewer viewer ships with a custom
`MarkdownGenerator`[^gen-ref] that threads inline footnote syntaxes
through the package's default parser.

[^gen-ref]: The generator lives in
    [lib/features/viewer/presentation/widgets/markdown_view.dart](https://github.com/cemililik/markdown-viewer-mobile/blob/main/lib/features/viewer/presentation/widgets/markdown_view.dart)
    and is cached per build to avoid re-allocating the syntax list
    on every render.

## Multiple footnotes in the same paragraph

The parser walks the full AST once[^walk], stamps each heading with
the index of its enclosing top-level block[^stamp], and records the
text + slug for the TOC drawer to consume[^drawer]. Three
independent footnote references, each opens its own sheet.

[^walk]: Depth-first walk that collects heading elements from
    anywhere in the parsed AST, not just top-level nodes.
[^stamp]: The block index lets the viewer map from a `HeadingRef`
    back to a widget key on the render side — see
    `_captureHeadingIndex`.
[^drawer]: The drawer lists headings in document order and hands
    each tap back to the viewer through `onHeadingSelected`.

## Footnote body formatting

A footnote body can carry inline marks and block content, subject
to the GFM rules.

Tap here[^rich] to see a footnote with **bold**, *italic*, a link,
and a code span.

[^rich]: This footnote demonstrates **bold**, *italic*,
    `inline code`, ~~strikethrough~~, and a link to
    [the project repo](https://github.com/cemililik/markdown-viewer-mobile).

## Numeric-style vs. word-style labels

The label inside `[^label]` is arbitrary. These render identically
regardless of what you choose:

- See the note on numbers[^1].
- See the note on words[^philosophy].
- See the note on mixing[^perf-a].

[^1]: A numeric label is the shortest form. Use when no other
    label naturally describes the referenced content.
[^philosophy]: A word label keeps the markdown source legible —
    easier to see which reference ties to which body.
[^perf-a]: Mixed-style labels are also fine as long as each is
    unique within the same document.

## Footnote ordering

The viewer renders footnote references in the order they appear in
the source text. The reference tap opens a sheet with the matching
body regardless of the body's position in the file, so you can keep
all footnote definitions at the end of the document for
readability — GitHub convention.
