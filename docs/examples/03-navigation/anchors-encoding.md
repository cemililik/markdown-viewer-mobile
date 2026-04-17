# Anchors — encoding variance

The viewer normalises anchor hrefs so the same heading can be
reached through several link shapes. This file's four sections
each link to the same headings in different styles — every tap
should land on the same place.

## Target: My Heading

A plain ASCII heading, slug `my-heading`. The four links below all
resolve here.

- Canonical: [jump](#my-heading)
- Mixed case: [jump](#My-Heading)
- Upper case: [jump](#MY-HEADING)
- Plus-as-space: [jump](#my+heading)

## Target: my heading with spaces

This heading's slug is `my-heading-with-spaces` (spaces → hyphens).
But if an author hand-writes the URL-encoded form with `%20` for
the literal space, the viewer still resolves it:

- With `%20`: [link](#my%20heading%20with%20spaces)

(It won't match the actual slug — it tries the percent-decoded
form against the heading's plain text too. In this case the
decoded form `my heading with spaces` does not equal the slug, but
the normalisation layer tries both directions.)

## Target: Türkçe başlık

Turkish heading with characters outside ASCII. The slug is
`türkçe-başlık`. A renderer that percent-encodes those bytes produces
hrefs like `t%C3%BCrk%C3%A7e-ba%C5%9Fl%C4%B1k`. Both forms resolve:

- Plain: [jump](#türkçe-başlık)
- Percent-encoded: [jump](#t%C3%BCrk%C3%A7e-ba%C5%9Fl%C4%B1k)

## Target: 日本語の見出し

CJK characters survive the slug pipeline identically — the
`\p{L}` class keeps them. Slug: `日本語の見出し`. A URL-encoded
form would be `%E6%97%A5%E6%9C%AC%E8%AA%9E%E3%81%AE%E8%A6%8B%E5%87%BA%E3%81%97`.

- Plain: [jump](#日本語の見出し)
- Percent-encoded: [jump](#%E6%97%A5%E6%9C%AC%E8%AA%9E%E3%81%AE%E8%A6%8B%E5%87%BA%E3%81%97)

## Summary

Every tap in this file should scroll to one of the four target
headings above. If a tap does not scroll, it is a bug — please
file an issue at
https://github.com/cemililik/markdown-viewer-mobile/discussions.
