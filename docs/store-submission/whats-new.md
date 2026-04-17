# What's new — v1.0.0

This is the copy the `release.yml` workflow reads from the annotated
tag message and pushes to:

- **Play Console** "What's new" field (truncated to 450 bytes)
- **GitHub Release** body

Apple TestFlight currently does not read release notes from the tag —
testers see the last note left on the previous build until we wire up
the App Store Connect API.

---

## Annotated tag body (English)

```
First public release of MarkdownViewer.

- Offline markdown reader with mermaid diagrams, LaTeX math,
  syntax-highlighted code, GFM tables, task lists, footnotes, and
  GitHub-style admonitions.
- Reading comfort: Material 3 themes (light/dark/sepia), adjustable
  font size + reading width + line height, immersive scroll, TOC
  drawer, in-document search, reading-position bookmark.
- GitHub sync: pull any public or private repository's markdown tree
  into the local library and read offline. Incremental re-sync;
  personal access token stored in the platform Keychain/Keystore.
- PDF export with mermaid diagrams preserved.
- Privacy: no accounts, no tracking, no background traffic. Crash
  reporting is opt-in and excludes document content, file paths,
  and tokens.

Apache-2.0 licensed. Source: github.com/cemililik/markdown-viewer-mobile
```

When you run `git tag -a v1.0.0`, paste the block above (without the
triple backticks) as the message. The `release.yml` workflow extracts
it via `git tag -l --format='%(contents)'`.

## Per-store trimmed versions

Google Play hard-caps the "What's new" field at 500 bytes per
locale. The workflow's `head -c 450` step auto-truncates the tag
message; if you want a cleaner cut, use the version below:

```
First public release of MarkdownViewer.

• Full CommonMark + GFM + mermaid + LaTeX math
• Reading-comfort toolbar (themes, font size, reading width)
• GitHub repository sync with offline cache
• PDF export with diagrams preserved
• Privacy-respecting: no tracking, no accounts, no background traffic
```

(Fits in 450 bytes including the newlines.)

Apple's "Version 1.0" **What's new** field has no byte limit in
practice (accepts 4000 chars), so use the long annotated-tag body.
