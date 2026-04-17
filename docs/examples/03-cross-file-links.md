# Cross-file links

Markdown links can point to other `.md` files in the same
directory. The viewer opens them in a new page so the back arrow
returns to this file.

## Sibling file

The companion file [03-cross-file-target.md](03-cross-file-target.md)
lives next to this one. Tap the link — the viewer pushes a new
route, parses the target, and renders it. Tap the back arrow in
the app bar to come back.

## Relative path with `..`

Links can also traverse directory boundaries. The TOC sits at
[docs/roadmap.md](../roadmap.md) one level above this one. Tap
it to jump over.

(Applies only when this file is opened from a folder / synced
repo that actually contains `docs/roadmap.md` at that relative
path. When opened as a standalone file from, say, AirDrop, the
relative path won't resolve and the tap is a no-op — see the log
line in the terminal if you're developing locally.)

## Cross-file anchors

A link can target both a file *and* a heading within that file by
adding a `#fragment` suffix. The viewer opens the target file and
scrolls to the heading automatically.

- [go to the heading inside the sibling](03-cross-file-target.md#a-specific-heading)

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
