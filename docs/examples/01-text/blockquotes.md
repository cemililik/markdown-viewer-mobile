# Blockquotes

A quote marker (`>`) at the start of a line opens a blockquote. The
viewer renders them with a left border in the primary colour and a
slight background tint so a long passage stays visually distinct
from the surrounding prose.

## Single-paragraph quote

> "The only way to go fast is to go well." — Robert C. Martin

## Multi-paragraph quote

> A blockquote can span multiple paragraphs. Every line of the
> paragraph needs its own `>` marker.
>
> A blank line (with `>` alone) separates the paragraphs inside the
> same quote block.
>
> The viewer preserves paragraph spacing so the reader can tell
> where one thought ends and the next begins.

## Nested quotes

> Outer quote.
>
> > Nested quote (the speaker is now inside the outer speaker's
> > words).
> >
> > > And a third level, if the source material is deeply
> > > recursive.
> >
> > Back to the second level.
>
> And the outer again.

## Formatted content inside quotes

> A quote can carry **bold text**, *italic text*, ~~strikethrough~~,
> `inline code`, and even [links](https://example.com).
>
> ```dart
> // Fenced code blocks too.
> final greeting = 'Hello from inside a quote';
> ```
>
> - Bullet lists
> - Work just fine
> - Inside quotes

## Attribution convention

A common convention is to separate attribution from the quoted
text with an em-dash:

> Any sufficiently advanced technology is indistinguishable from
> magic.
>
> — Arthur C. Clarke

## Not a blockquote — an admonition

GitHub-style admonitions start with `> [!NOTE]` on the first line
and render with an icon, coloured border, and title — see
[admonitions.md](../02-blocks/admonitions.md).
