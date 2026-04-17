# MarkdownViewer examples

A feature-by-feature tour of everything the viewer renders. Each
file demonstrates one surface — open them in the app to see the
feature in real Material-3 typography and theming.

This directory is what the **"Try it"** card on the sync screen
syncs. One tap imports the full tree; you can open any file from
the library drawer afterwards and read offline.

## Folder structure

The files are grouped into subdirectories so you can also
experience the **folder explorer** in the library drawer — tap a
folder to enter it, tap the back arrow to return. Cross-file
links inside the samples exercise `..`-traversal between folders.

```text
docs/examples/
├── README.md                ← this file
├── 01-text/                 ← prose building blocks
│   ├── formatting.md
│   ├── lists.md
│   └── blockquotes.md
├── 02-blocks/               ← block-level markdown
│   ├── tables.md
│   ├── code.md
│   ├── admonitions.md
│   └── footnotes.md
├── 03-navigation/           ← links and anchors
│   ├── anchors-basic.md
│   ├── anchors-encoding.md
│   ├── cross-file-links.md
│   └── cross-file-target.md
├── 04-math.md               ← LaTeX math (inline + display)
└── 05-mermaid/              ← every mermaid diagram type
    ├── flowchart.md
    ├── sequence.md
    ├── class.md
    ├── state.md
    ├── er.md
    ├── gantt.md
    ├── pie.md
    ├── journey.md
    ├── mindmap.md
    ├── timeline.md
    ├── gitgraph.md
    └── quadrant.md
```

## Text + structure

| File | Demonstrates |
|------|--------------|
| [01-text/formatting.md](01-text/formatting.md) | Bold, italic, strikethrough, inline code, links (inline / reference / autolink / anchor / cross-file), hard/soft line breaks, escapes, horizontal rules, Unicode round-trip |
| [01-text/lists.md](01-text/lists.md) | Unordered, ordered, nested, task lists (all GFM states), multi-paragraph list items, deeply mixed content |
| [01-text/blockquotes.md](01-text/blockquotes.md) | Single- and multi-paragraph quotes, nesting three levels deep, quotes with formatted content / code / lists |

## Block-level markdown

| File | Demonstrates |
|------|--------------|
| [02-blocks/tables.md](02-blocks/tables.md) | Basic GFM tables, column alignment, inline markdown in cells, wide tables with horizontal scroll, numeric data |
| [02-blocks/code.md](02-blocks/code.md) | Syntax highlighting across Dart, Kotlin, Swift, TypeScript, Python, Rust, Go, Shell, SQL, JSON, YAML |
| [02-blocks/admonitions.md](02-blocks/admonitions.md) | GitHub-style NOTE / TIP / IMPORTANT / WARNING / CAUTION, multi-paragraph bodies, code and lists inside admonitions |
| [02-blocks/footnotes.md](02-blocks/footnotes.md) | Single and multiple footnotes per paragraph, rich-formatting inside footnote bodies, numeric / word label styles |

## Navigation

| File | Demonstrates |
|------|--------------|
| [03-navigation/anchors-basic.md](03-navigation/anchors-basic.md) | Heading slug rules, manual TOC, duplicate-heading disambiguation |
| [03-navigation/anchors-encoding.md](03-navigation/anchors-encoding.md) | Case-insensitive lookup, percent-encoded ASCII / Turkish / CJK slugs, `+`-as-space |
| [03-navigation/cross-file-links.md](03-navigation/cross-file-links.md) | Sibling / `..`-traversal / cross-file + anchor links, non-markdown link drop, external URL fallthrough |
| [03-navigation/cross-file-target.md](03-navigation/cross-file-target.md) | Landing page for the cross-file example above |

## Math

| File | Demonstrates |
|------|--------------|
| [04-math.md](04-math.md) | Inline `$…$` and display `$$…$$` LaTeX: fractions, integrals, sums, matrices, `aligned`, `cases`, literal dollar escapes |

## Mermaid diagrams

| File | Demonstrates |
|------|--------------|
| [05-mermaid/flowchart.md](05-mermaid/flowchart.md) | Flowcharts: TB / LR directions, every node shape, every edge type, subgraphs, `classDef` styling |
| [05-mermaid/sequence.md](05-mermaid/sequence.md) | Sequence diagrams: activation bars, `alt` branches, `loop`, `par` parallel regions, notes over participants |
| [05-mermaid/class.md](05-mermaid/class.md) | Class diagrams: fields and methods, composition / inheritance / implementation, cardinality, `<<abstract>>` and `<<enumeration>>` stereotypes |
| [05-mermaid/state.md](05-mermaid/state.md) | State diagrams: nested (composite) states, parallel regions, guarded transitions, state-level notes |
| [05-mermaid/er.md](05-mermaid/er.md) | Entity-relationship diagrams: cardinality notation, multi-table schemas, attributes with PK/FK |
| [05-mermaid/gantt.md](05-mermaid/gantt.md) | Gantt charts: sections, parallel tracks, dependencies (`after`), milestones, critical tasks |
| [05-mermaid/pie.md](05-mermaid/pie.md) | Pie charts: with `showData`, with titles, with multiple slice counts |
| [05-mermaid/journey.md](05-mermaid/journey.md) | User journey maps: sections, per-step scores, multiple actors per task |
| [05-mermaid/mindmap.md](05-mermaid/mindmap.md) | Mindmaps: deep nesting, feature overviews, architecture layer trees |
| [05-mermaid/timeline.md](05-mermaid/timeline.md) | Timelines: dated events, unified section groupings, multi-line entries |
| [05-mermaid/gitgraph.md](05-mermaid/gitgraph.md) | Git graphs: feature branches, concurrent branches, merges, cherry-picks, release trains |
| [05-mermaid/quadrant.md](05-mermaid/quadrant.md) | Quadrant charts: two-axis prioritisation, explicit quadrant labels, multiple data points |

## How to use

1. Open the sync screen in the app (drawer → **Sync repository**).
2. Tap the **"Try it"** card — it pre-fills this directory's
   GitHub URL.
3. The sync downloads the whole tree — folders included — into
   local storage; you can now open any file from the library
   drawer and navigate through the folder structure.
4. Tap headings in the TOC drawer, follow cross-file links (`..`
   between folders!), flip themes (Settings → Theme), try
   in-doc search — every feature the app advertises has a sample
   here.

Offline after sync — the GitHub URL is only used to fetch the
files; reading them does not require network.

## Contributing

Found a rendering edge case these files don't exercise? Open an
issue or PR at
[github.com/cemililik/markdown-viewer-mobile](https://github.com/cemililik/markdown-viewer-mobile).
New samples go into the category folder that best fits and should
demonstrate one specific feature per file.
