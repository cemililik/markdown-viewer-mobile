# Cross-file links

Markdown links can point to other `.md` files in the same folder
or elsewhere in the synced tree. The viewer opens the target in a
new page so the back arrow returns to this file.

## Sibling file (same folder)

The companion file [cross-file-target.md](cross-file-target.md)
lives right next to this one in `03-navigation/`. Tap the link —
the viewer pushes a new route, parses the target, and renders it.
Tap the back arrow in the app bar to come back.

## Relative path with `..` (another folder)

Links can traverse folder boundaries. A link into the math
section sits two directory hops away via `..`:

- [jump to the math example](../04-math.md)

And into the mermaid folder one hop down again:

- [jump to mermaid flowcharts](../05-mermaid/flowchart.md)

(Both work only when this file is opened from the synced tree
that actually contains those siblings. When opened as a standalone
file via AirDrop / file share, the relative path has no sibling
folder to resolve into and the tap is a quiet no-op.)

## Cross-file anchors

A link can target both a file *and* a heading within that file by
adding a `#fragment` suffix. The viewer opens the target file and
scrolls to the heading automatically.

- [the heading inside the sibling](cross-file-target.md#a-specific-heading)
- [a heading two folders away](../05-mermaid/flowchart.md#subgraphs)

## Non-markdown links

Only `.md` / `.markdown` targets are accepted. A link to
`[see our logo](logo.png)` silently drops — the viewer refuses to
produce filesystem paths for non-markdown targets (it is a reader,
not an image viewer).

## External links still work

Regular external links use the platform browser:

- [MarkdownViewer on GitHub](https://github.com/cemililik/markdown-viewer-mobile)
- [GFM spec](https://github.github.com/gfm/)

Tapping one of these hands the URL to the system and the viewer
stays open in the background.
