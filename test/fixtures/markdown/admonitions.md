# Admonitions

Five GitHub-style alert blocks, one of each kind, plus a couple of
regression cases. Section headings deliberately avoid the literal
kind names (`Note`, `Tip`, …) so widget tests can match the
admonition title text without colliding with a heading of the same
name.

## Informational example

> [!NOTE]
> This is an informational alert. It explains a concept without
> calling out risk.

## Suggestion example

> [!TIP]
> Tips suggest a better way — often with a **bold phrase** and an
> inline `code span`.

## Must-read example

> [!IMPORTANT]
> Important alerts flag something the reader must not miss. Nested
> content like a [link to example.com](https://example.com) must
> still render.

## Risky-action example

> [!WARNING]
> Warnings highlight risky actions or surprising behaviour.

## Hazard example

> [!CAUTION]
> The strongest alert — reserved for data loss or security hazards.

## Plain blockquote regression

This blockquote must keep its default rendering because it does not
start with a `[!KIND]` marker:

> Just a normal quoted paragraph. No icon, no themed container.

## Unknown kind regression

A blockquote whose first line looks like an alert but uses a kind
the parser does not recognise should fall through to the default
blockquote rendering:

> [!UNKNOWN]
> Should render as a normal blockquote, not as an admonition.
