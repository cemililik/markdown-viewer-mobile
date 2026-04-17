# Anchors — the basics

Every heading in a markdown document implicitly gets an **anchor
slug**: a URL-safe identifier derived from the heading text. You
can link to any heading from anywhere in the same document by
writing `[label](#slug)`.

## Table of contents

- [Introduction](#introduction)
- [Slug rules](#slug-rules)
- [Examples](#examples)
- [Duplicate headings](#duplicate-headings)

## Introduction

Tap any entry above and the viewer scrolls straight to that heading
— no page reload, no network call. This is a pure in-document
jump, identical to how GitHub renders heading links on the web.

Jump back up: [go to the top](#anchors-the-basics).

## Slug rules

The parser applies this pipeline to the heading text:

1. Lowercase the entire string.
2. Strip every character that is not a letter, digit, whitespace,
   or hyphen.
3. Collapse whitespace runs into single hyphens.
4. Collapse hyphen runs into a single hyphen.
5. Trim leading and trailing hyphens.

So `## Getting Started` → `getting-started`, `## API Reference!` →
`api-reference`, `## Çözüm önerileri` → `çözüm-önerileri`.

See the [introduction](#introduction) again — the jump works even
when you link backwards.

## Examples

| Heading as written | Generated slug |
|---|---|
| `# Anchors — the basics` | `anchors-the-basics` |
| `## Slug rules` | `slug-rules` |
| `## Heading (with parens)` | `heading-with-parens` |
| `## Çözüm önerileri` | `çözüm-önerileri` |

The first row shows the whitespace-collapse step at work: the em
dash (`—`) is stripped as a non-letter/digit/whitespace/hyphen
character, leaving two consecutive spaces between `anchors` and
`the basics`. The `\s+` regex matches the *entire* run of
whitespace as one token and replaces it with a single hyphen —
that is why the slug ends up with `anchors-the-basics`, not
`anchors--the-basics`.

## Duplicate headings

If two headings share the same slug, the parser disambiguates by
appending `-1`, `-2`, and so on to every occurrence *after* the
first:

### Same Title

First occurrence — slug is `same-title`.

### Same Title

Second occurrence — slug is `same-title-1`. [Link to the
second](#same-title-1) to verify.

### Same Title

Third occurrence — slug is `same-title-2`. [Link to the
third](#same-title-2) to verify.
