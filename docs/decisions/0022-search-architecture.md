# ADR-0022: Search architecture and rendered-text mapping

- **Status**: Accepted
- **Date**: 2026-07-30
- **Deciders**: Cemil Ilık
- **Owner**: Cemil Ilık
- **Revisit date**: 2026-10-30
- **Depends on**:
  [ADR-0004](0004-markdown-rendering.md),
  [ADR-0007](0007-local-storage.md)

This ADR proposes one search architecture for open documents and the
folder-, repository-, and recent-document corpus.

## Context

In-document search currently scans raw markdown and then injects markers
back into the source. Its counter, highlighter, and jump behavior can use
different match sets. Raw-source offsets can corrupt links and footnote
labels, cannot find text across formatting boundaries, and do not point to
stable rendered blocks.

Library search has multiple source types with different storage and
enumeration mechanisms:

- native-backed folder trees selected by the user;
- application-owned mirrors created by repository sync; and
- recent documents, which can overlap either source.

Corpus construction and search can duplicate tens of megabytes across
isolates. Static review does not establish whether full document
virtualization is beneficial, and a premature virtualization design could
break off-screen heading and match jumps.

## Decision

### Corpus ownership and source adapters

- `LibraryContentSearch` remains a domain port. Data-layer adapters obtain
  candidates from native folder enumeration, the repository mirror, and
  the recent-document store.
- Every candidate is normalized to one canonical `DocumentId`. Recents
  contribute ranking information, not a duplicate document.
- Source adapters return metadata and a content handle. Presentation
  labels and `BuildContext` never cross the domain boundary.
- File access obeys the shared document size and encoding policy before
  decoded text enters the corpus.
- A source failure is retained as a typed partial-search diagnostic. A
  failed source is not presented as a confident empty result.

### One applied match list

- A completed query produces one immutable, filtered match list.
- The result counter, visible highlights, current-match index, and jump
  target read only that list and its query snapshot.
- Closing search cancels debounce and outstanding work. Results carry a
  document and query generation; stale generations cannot apply.
- The W1 implementation filters raw-source matches consistently. It
  excludes fenced and inline code, Mermaid source, link destinations, and
  stripped footnote definitions from the counter, highlight, and jump
  target together.
- Highlighting never inserts marker characters into link destinations,
  footnote labels, code, or other syntax-bearing source ranges.

### Text normalization

- Search keys and candidate text are normalized to Unicode NFC.
- Matching uses Unicode default case folding, not locale-sensitive
  `toLowerCase`. Displayed text retains its original spelling.
- Normalization maintains an offset map back to the original text so
  composed and decomposed forms highlight the correct grapheme range.
- Cross-library search starts only after three user-perceived characters.
  In-document search may run from one character because its corpus is
  already bounded to the open document.

### Rendered-text index

- The long-term in-document index is built from the shared markdown AST,
  after syntax that is not rendered as prose has been identified.
- Each index segment records:
  - normalized rendered text;
  - its AST node identity;
  - its source range when one exists;
  - its stable block or heading anchor; and
  - an intra-block rendered range.
- Adjacent inline nodes in the same rendered block share a searchable text
  stream, so a phrase crossing a bold, emphasis, or link-label boundary is
  discoverable.
- Search results jump to the owning block anchor and then to an
  intra-block position after layout settles. They do not estimate a scroll
  offset from source length.
- Dynamic diagram layout may trigger jump resolution again, but does not
  rebuild the text index when document content is unchanged.

### Isolate transfer and budgets

- Corpus bytes cross an isolate boundary once per search generation using
  `TransferableTypedData`. Workers do not receive both a decoded `String`
  corpus and a byte copy.
- The decoded cross-library corpus has a hard **50 MiB** per-generation
  budget. Files excluded by size remain visible as typed diagnostics.
- A query returns at most **500 document results** and at most **100
  snippets per document**. The worker may stop collecting lower-ranked
  results after those limits.
- Inner scanning compares code units or normalized scalar buffers without
  allocating a new `String` per character.
- Latency and frame budgets are set and enforced by the benchmark suite,
  not inferred from static review. Budget changes require benchmark
  evidence in the pull request.

### Ranking and determinism

- Ranking considers match quality, title or heading match, recent-open
  signal, and stable source order.
- Equal scores resolve by canonical `DocumentId`, making repeated searches
  deterministic.
- Ranking never changes the filtered match set used inside an open
  document.

### Virtualization measurement checkpoint

This ADR does **not** choose full document virtualization.

After the benchmark gate is running and parse/rebuild memoization has
landed, the owner must profile representative small, large, and
diagram-heavy documents on the fixed low-end device. A separate ADR will
decide whether to:

- keep the materialized document with per-block repaint boundaries; or
- virtualize blocks while preserving off-screen anchor jumps, selection,
  and a stable scrollbar extent.

No virtualization implementation begins from static estimates alone. The
rendered-text block index is designed to support either outcome.

### Verification

Tests must demonstrate:

- one match list drives count, highlight, and jump;
- closing or replacing a query prevents stale results from applying;
- NFC and decomposed input match the same original grapheme range;
- Turkish casing follows Unicode case-folding behavior consistently;
- syntax-bearing and excluded ranges are never modified;
- a phrase spanning inline formatting is found by the rendered-text index;
- folder, mirrored-repository, and recent sources deduplicate by
  `DocumentId`;
- `TransferableTypedData` is the only corpus payload sent to the worker;
- size and result budgets produce typed, visible outcomes; and
- benchmark budgets fail CI when regressed.

## Consequences

### Positive

- Search count, highlight, and navigation cannot disagree.
- Rendered-text search matches what the reader can see.
- Folder, repository, and recent sources share one tested contract.
- Unicode normalization produces stable behavior across supported locales.
- Explicit transfer and result budgets bound memory and response size.
- The block index can later support measured virtualization without
  predetermining it.

### Negative

- Maintaining normalized-to-original offset maps adds algorithmic
  complexity.
- The W1 filtered-source stage is transitional until rendered-text mapping
  lands.
- Partial-source diagnostics add UI states beyond results and empty.
- Corpus limits can omit files from one search generation.
- A separate measured virtualization decision is still required.

## Alternatives considered

### Continue searching raw markdown

Rejected because raw syntax is not the user's visible document and cannot
represent phrases split across inline formatting.

### Maintain separate match lists for counting and highlighting

Rejected because filtering drift is the direct cause of misleading counts
and invalid jump targets.

### Pass decoded strings to every isolate invocation

Rejected because it duplicates the corpus and makes memory proportional to
both source count and worker lifecycle.

### Build a persistent full-text database now

Rejected because the corpus is user-selected and mutable, search
requirements are not yet measured, and persistent indexing adds
invalidation and privacy lifecycle obligations before they are justified.

### Virtualize the viewer immediately

Rejected pending measurements. Virtualization is not a search correctness
fix and can regress navigation, selection, and scroll stability.

## Revisit criteria

Cemil Ilık will review this decision on **2026-10-30**, after the
benchmark gate, parse memoization, and rendered-text mapping have produced
profile data. That review must either open the separate virtualization ADR
with measured evidence or record that materialization remains within the
budgets.
