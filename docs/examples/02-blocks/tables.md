# Tables (GFM)

GitHub-flavored pipe-separated tables. The viewer applies the
Material-3 surface container tint to the header row, and each
column inherits the alignment declared in the divider row.

## Basic table

| Column A | Column B | Column C |
|----------|----------|----------|
| a1       | b1       | c1       |
| a2       | b2       | c2       |
| a3       | b3       | c3       |

## Alignment

Column alignment is encoded in the colons of the divider row.

| Left-aligned | Center-aligned | Right-aligned |
|:-------------|:--------------:|--------------:|
| a            | b              | c             |
| longer cell  | another cell   | 42            |
| x            | y              | 1_000_000     |

## Cells with inline markdown

| Feature          | Status        | Notes                                |
|------------------|---------------|--------------------------------------|
| **Bold**         | ✅ works      | renders with Material weight 700     |
| *Italic*         | ✅ works      | same treatment as in body prose      |
| ~~Strikethrough~~ | ✅ works      | decoration preserved                 |
| `Inline code`    | ✅ works      | monospace cell content               |
| [Link](https://example.com) | ✅ works | tap opens the URL          |
| Images in cells  | ⚠️ limited    | plain text only; images not rendered inline |
| Line break (`<br>`) | ❌ not rendered | HTML stays as literal text       |

## Wide tables

A table wider than the viewport triggers horizontal scroll on the
table block itself — the rest of the page keeps its normal vertical
scroll position.

| Hash | Author | Date       | Subject                                          | Files | +/− |
|------|--------|------------|--------------------------------------------------|-------|-----|
| a1b2 | alice  | 2026-04-01 | refactor(viewer): extract anchor resolver        | 4     | +120/-43 |
| c3d4 | bob    | 2026-04-02 | fix(sync): token allow-list rejects other hosts  | 2     | +25/-3   |
| e5f6 | carol  | 2026-04-03 | docs(examples): mermaid sequence + class samples | 12    | +480/-0  |
| g7h8 | dave   | 2026-04-04 | perf(search): move scan to background isolate    | 1     | +18/-9   |

## Numeric data

| Metric                 | Value  | Unit   |
|------------------------|-------:|:-------|
| Parse budget           |    200 | ms     |
| Build budget           |    150 | ms     |
| Mermaid render budget  |    800 | ms     |
| Per-file sync cap      |      5 | MB     |
| Discovery cap          |     25 | MB     |
| App cold-start target  | <1,500 | ms     |

## Small table (one column)

| Theme    |
|----------|
| Light    |
| Dark     |
| Sepia    |
| System   |
