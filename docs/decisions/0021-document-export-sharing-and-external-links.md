# ADR-0021: Document export, sharing, and external links

- **Status**: Accepted
- **Date**: 2026-07-30
- **Deciders**: Cemil Ilık
- **Owner**: Cemil Ilık
- **Revisit date**: 2027-01-30
- **Depends on**:
  [ADR-0004](0004-markdown-rendering.md),
  [ADR-0011](0011-network-access-policy.md)

This ADR proposes one trustworthy document pipeline for PDF export,
sharing, and user-initiated external navigation.

## Context

The viewer and PDF exporter currently parse and interpret the same
markdown independently. Their parser configurations and supported
structures have drifted, so math, admonitions, footnotes, links, images,
and nested Mermaid blocks can render differently or disappear in an
export. The exporter also removes code points outside Latin-1, which can
silently delete Turkish and other scripts.

Sharing has separate filename-cleaning paths, does not consistently
inspect the platform share result, and leaves temporary files behind.
On iPad, presenting a share sheet without an anchor can fail. Export is a
long-running operation without reliable progress, cancellation, or a
re-entrancy boundary.

External links cross from an untrusted local document into another
application. The user needs to see the destination origin before that
handoff. Launching a link is not permission for this application to fetch
it, and must not weaken ADR-0011.

The design must preserve feature-layer boundaries: pure parsing and
export orchestration belong in the viewer application layer, platform and
file-system operations remain behind domain ports, and presentation owns
localized prompts.

## Decision

### One parse and one document model

- The viewer and every export target use the same markdown configuration
  factory and the same immutable AST-derived document model.
- A document is parsed once per export operation. Target renderers consume
  typed nodes and never re-parse raw markdown.
- Diagram exports are associated with AST node identities, not positional
  counters. A platform WebView may render Mermaid snapshots before the
  pure PDF stage starts; the WebView itself never moves to an isolate.
- Unsupported nodes preserve meaningful text or alt text and produce a
  typed, testable diagnostic. They are never silently discarded.

### PDF rendering

- PDF rendering preserves block structure and supports page-spanning
  content, links, images or image alt text, code blocks, math,
  admonitions, footnotes, and Mermaid snapshots.
- The heading tree supplies the document title and PDF outline. The
  first-class PDF phase also adds page numbers and a running header.
- User-visible PDF strings and preflight messages come from ARB resources.
  Raw engine diagnostics are not embedded in the document.
- Export metadata is derived from the document title with the sanitized
  filename as a fallback.

### Unicode font strategy

- PDF assets bundle a size-controlled set of Noto fonts and fallbacks.
  The initial font contribution has a hard release budget of **5 MiB
  compressed** across Android and iOS artifacts.
- A committed font manifest records each font's upstream version, SHA-256,
  licence, compressed and uncompressed size, and supported Unicode ranges.
- Export performs glyph-coverage preflight before creating a file.
  Supported text uses the smallest matching fallback chain.
- If the bundled fonts do not cover a code point, export stops before
  writing a misleading PDF and presents a localized message that explains
  the unsupported script and offers source sharing instead.
- Document text is never filtered by code-point range and unsupported
  glyphs are never silently removed or replaced with empty text.
- Fonts are never downloaded at runtime. A future downloadable font pack
  would require a new ADR and an explicit amendment to ADR-0011.

### Asynchronous operation lifecycle

- Export is an application-layer operation with typed phases: preflight,
  parse, diagram preparation, layout, write, and share.
- CPU-only parsing and PDF layout execute off the UI isolate. Platform
  WebView, share-sheet, and file-picker interactions remain on their
  required platform thread.
- Progress reports the current phase and bounded work where a total is
  known. The UI prevents duplicate starts for the same document.
- Cancellation propagates through every cancellable phase and is checked
  between non-interruptible platform operations. Cancellation never
  reports success and never leaves a partial destination file.
- Failure and cancellation paths clean up the same resources as success.

### Filenames, temporary files, and share sheets

- One `buildShareFilename` policy sanitizes both markdown and PDF names.
  It rejects path separators, control and bidi-override characters,
  dot-only names, leading dot-files, trailing spaces or dots, and reserved
  platform device names.
- Sanitization always produces a non-empty basename before adding exactly
  one target extension.
- Temporary share files use collision-resistant names inside an
  application-owned temporary directory.
- Temporary files are deleted after success, cancellation, or failure.
  A bounded startup cleanup removes abandoned files left by process death.
- Share results are inspected and mapped to success, dismissal,
  unavailable service, or typed failure.
- Every iPad share presentation supplies a source rectangle anchored to
  the initiating control.

### External-link handoff

- Document-authored links never trigger an application HTTP request.
- Before handing an external URI to the operating system, the app shows a
  localized confirmation containing the normalized destination origin.
- `https` is the normal external scheme. `http` requires an explicit
  insecure-transport warning. `mailto` and `tel` show their normalized
  destination and require confirmation. All other external schemes are
  rejected unless a later ADR allow-lists them.
- URIs containing embedded credentials or control characters are rejected.
  The displayed origin and launched URI come from the same normalized,
  parsed value. An invalid or ambiguous URI is rejected rather than
  repaired speculatively.
- The confirmation cannot grant persistent trust to a document or host.
  Every external handoff remains an explicit user action.

### Verification

Tests must demonstrate:

- parser parity between viewer and export for every custom block;
- Turkish text survives and unsupported scripts take the localized
  preflight path without writing a PDF;
- a multi-page fixture paginates and produces heading outline entries,
  page numbers, and running headers;
- filenames are safe across Android, iOS, and common desktop-reserved
  names even though desktop is not a supported target;
- temporary files are removed on success, failure, and cancellation;
- iPad share requests always contain an anchor;
- external-link confirmation displays the normalized origin and rejects
  blocked schemes; and
- cancellation and re-entrancy cannot report a false success.

## Consequences

### Positive

- Viewer and export semantics cannot drift through separate parsers.
- Non-Latin text is preserved when supported and fails visibly when not.
- Export remains responsive and recoverable on large documents.
- Sharing is predictable across platforms and does not accumulate files.
- External navigation is explicit without expanding in-app network access.
- The heading model supports both viewer navigation and first-class PDF
  artifacts.

### Negative

- Bundled fonts increase both application artifacts by up to the stated
  budget.
- Glyph preflight and a font manifest add release-maintenance work.
- A complete AST-to-PDF renderer is more code than text flattening.
- Mermaid export crosses a platform-thread preparation boundary before
  pure isolate work can begin.
- Confirming every external handoff adds friction for frequent links.

## Alternatives considered

### Keep an independent PDF parser

Rejected because custom syntax and heading behavior would continue to
drift, and each new viewer feature would require a second implementation.

### Bundle fonts for every Unicode script

Rejected for the initial decision because CJK and specialist font families
would add a disproportionate binary-size cost. Explicit preflight is safer
than silent corruption while coverage is expanded deliberately.

### Download missing fonts on demand

Rejected because it violates the current network boundary, introduces
font-supply-chain and privacy risks, and makes export depend on network
availability.

### Continue export on unsupported glyphs

Rejected because replacement boxes or deleted text produce an artifact
that appears successful while changing the document.

### Launch external links without confirmation

Rejected because document-authored content is untrusted and the
application must not obscure the origin crossing.

## Revisit criteria

Cemil Ilık will review this decision on **2027-01-30** using shipped font
coverage, artifact-size measurements, export failure telemetry from
consenting users, and iPad share results. Earlier review is required if
the 5 MiB font budget is exceeded, a supported app locale is not covered,
or runtime font acquisition is proposed.
