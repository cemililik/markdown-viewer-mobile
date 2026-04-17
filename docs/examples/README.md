# MarkdownViewer examples

Sample `.md` files that demonstrate specific features. Open any of
them in the app (Files → Open, or drop them into a folder source)
to exercise the feature end-to-end.

## Files in this directory

| File | Demonstrates |
|------|--------------|
| [01-anchors-basic.md](01-anchors-basic.md) | In-document anchor links with a manual table of contents |
| [02-anchors-encoding.md](02-anchors-encoding.md) | Anchor normalisation: case, percent-encoding, `+`-as-space, Unicode slugs |
| [03-cross-file-links.md](03-cross-file-links.md) | Relative file links between two `.md` files in the same directory |
| [03-cross-file-target.md](03-cross-file-target.md) | Target file opened by the cross-file example above |

## How to use

1. Sync this repository from the in-app sync screen — the
   MarkdownViewer "Try it" card pre-fills the repo URL.
2. Open the synced `docs/examples/` folder in the library drawer.
3. Tap any of the four files.
4. Taps on heading links (e.g. `[section](#my-heading)`) scroll the
   viewer to that heading.
5. Taps on relative file links (e.g. `[see](other.md)`) open the
   target file in a new viewer page — the back arrow returns you
   here.

All four files use the same slug rules the parser applies to the
rest of the app, so anything that works here works in your own
documents too.
