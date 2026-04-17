# Admonitions

GitHub-style admonitions — a blockquote opened with `> [!TYPE]` on
its first line. The viewer recognises the five standard kinds and
renders each with a matching icon, title colour, and left-border.

## Note

> [!NOTE]
> Useful information that users should know, even when skimming
> content. The note admonition is the neutral tone — good for
> "by the way" context that does not change what the user is
> doing but enriches their understanding.

## Tip

> [!TIP]
> Helpful advice for doing things better or more easily. Tips are
> the positive tone — green icon, motivating tone, often about
> shortcuts or best practices the reader can adopt.

## Important

> [!IMPORTANT]
> Key information users need to know to achieve their goal.
> Important admonitions sit between "note" and "warning" — not
> dangerous, but the reader should not skip over them.

## Warning

> [!WARNING]
> Urgent info that needs immediate user attention to avoid problems.
> The warning admonition flags things that may still work if the
> reader ignores them, but are likely to cause pain downstream.

## Caution

> [!CAUTION]
> Advises about risks or negative outcomes of certain actions.
> Caution is the strongest tone — use it sparingly, for things
> that will break if the reader does not heed the advice.

## Multi-paragraph admonitions

> [!NOTE]
> Admonitions can span multiple paragraphs.
>
> Continuation lines need their own `>` marker; a blank `>` line
> separates paragraphs inside the same admonition.
>
> Inline formatting works: **bold**, *italic*, `inline code`, and
> [links](https://github.com/cemililik/markdown-viewer-mobile) all
> render as they would in prose.

## Admonitions with code

> [!TIP]
> Admonition bodies can carry fenced code blocks:
>
> ```dart
> ref.watch(settingsStoreProvider).readingTheme;
> ```
>
> — useful for call-out snippets that are worth pulling out of the
> surrounding narrative.

## Admonitions with lists

> [!IMPORTANT]
> Before cutting a release:
>
> 1. Bump `pubspec.yaml`.
> 2. Promote the `[Unreleased]` CHANGELOG entry.
> 3. Run `flutter test` locally.
> 4. Push an annotated tag: `git tag -a v1.2.3 -m '...'`.

## Unrecognised admonition types

> [!INFO]
> An unknown type (`[!INFO]`, `[!DANGER]`, `[!FAQ]`, etc.) falls
> through to a plain blockquote — the viewer does not guess. Use
> one of the five documented types above or the text renders
> verbatim with the bracket syntax intact.
