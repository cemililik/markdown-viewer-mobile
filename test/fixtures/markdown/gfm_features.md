# GitHub-Flavoured Markdown Features

This fixture exercises every GFM extension we want `markdown_widget` to
render out of the box, so a regression in any of them is caught by the
matching widget test.

## Tables

| Tier   | Latency | Notes                       |
|--------|---------|-----------------------------|
| Local  | 5 ms    | Read from disk              |
| Synced | 50 ms   | Cached after first download |
| Remote | 500 ms  | Cold network call           |

## Task Lists

- [x] Write the parser
- [x] Wire the file picker
- [ ] Render mermaid diagrams
- [ ] Render LaTeX math

## Strikethrough

This sentence has ~~struck-out~~ text in the middle.

## Footnotes

Here is a sentence with a footnote reference.[^one] And another one[^two]
later in the same paragraph.

[^one]: First footnote body.
[^two]: Second footnote body, with **inline emphasis** inside.

## Autolinks

A bare URL like https://example.com/docs should become a tappable link
without explicit angle brackets.
