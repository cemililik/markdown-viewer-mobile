# ADR-0005: Mermaid via sandboxed InAppWebView

- **Status**: Accepted
- **Date**: 2026-04-12
- **Revised**: 2026-04-19 — Decision and Consequences sections
  updated to describe the PNG screenshot pipeline that was actually
  shipped. The original text spoke of returning SVG strings and
  rendering via `flutter_svg`; the implementation long since switched
  to `controller.takeScreenshot()` returning raw PNG bytes that are
  rendered via `Image.memory`. Reference: code-review CR-20260419-010.

## Context

Mermaid is defined as a JavaScript library. There is no pure-Dart port
with feature parity. Options:

1. Bundle `mermaid.min.js` and render via a sandboxed WebView
2. Render server-side (requires network, violates offline-first)
3. Re-implement a subset in Dart (unbounded cost, partial support)
4. Render to image at build time (does not work for user documents)

## Decision

- Bundle **`mermaid.min.js`** as an asset under
  `assets/mermaid/mermaid.min.js`.
- Use **`flutter_inappwebview`** (≥ 6) to create a single pre-warmed,
  headless, sandboxed WebView at app start (`HeadlessInAppWebView`).
- Expose a `MermaidRenderer` service (port in
  `lib/features/viewer/domain/services/mermaid_renderer.dart`,
  implementation in
  `lib/features/viewer/data/services/mermaid/mermaid_renderer_impl.dart`)
  that queues render requests through a single FIFO `_pump` so at
  most one mermaid render runs at a time.
- The renderer returns a **`Uint8List` of raw PNG bytes** captured
  via `controller.takeScreenshot()` after the JS side has finished
  layout. PNG was chosen over SVG because Android WebView's SVG
  `data:` URI round-trip drops embedded styles and breaks label
  hit-boxes on `gantt` / `sequence` diagrams; a screenshot preserves
  the rendered pixel grid byte-identically across platforms.
- Render returned PNGs inline via `Image.memory(bytes)` in
  `mermaid_block.dart`. The image size and the pixel ratio are also
  returned so the widget can request a CSS-pixel sized box matching
  what the WebView rendered.
- The LRU cache stores the PNG bytes keyed on
  `sha256(source + themeDirective)`. Cache hits reuse the same
  `Uint8List` and let Flutter's global image cache absorb decode
  cost (see code-review CR-20260419-005 / performance PR-005 for the
  decode-on-hit consequence).

### Rendering invariants the SVG-injection safety depends on

The mermaid WebView template (`mermaid_html_template.dart`) is
hardened with:

- `blockNetworkLoads: true` on the `InAppWebViewSettings`,
- `default-src 'none'` + `img-src 'none'` + `font-src 'none'` +
  `base-uri 'none'` + `form-action 'none'` in the page's CSP meta,
- `securityLevel: 'antiscript'` forced as the last merge key of the
  `%%{init:}%%` directive even when the user's source supplies its
  own override (see SR-20260419-014).

Relaxing any of these invariants requires a new ADR — the SVG's
`innerHTML` assignment path relies on this combination to neutralise
`<img onerror=…>` / `<a href="javascript:…">` attacks that
`antiscript` alone would not block.

## Consequences

### Positive

- Full mermaid feature parity with upstream.
- Offline-first — no network required at render time.
- Sandbox + hardened CSP keep untrusted diagram source on a short
  leash (see `docs/standards/security-standards.md`).
- PNG bytes are a stable contract: identical input yields an
  identical cache key regardless of theme / text direction, so the
  LRU hit rate is predictable.

### Negative

- WebView adds ~5 MB to the binary.
- The first mermaid render pays a one-time WebView warm-up cost;
  subsequent renders reuse the live `HeadlessInAppWebView` instance.
- Prewarm was on the cold-start critical path until v1.2.0 (now
  deferred to the first post-frame callback — see PR-20260419-008).
- The single shared WebView serialises every render through the
  `_pump` queue, so a document with many diagrams renders them in
  strict FIFO order rather than in parallel.
- Upgrading mermaid requires bundling a new JS file
  (`tool/fetch_mermaid.sh`).
- Cache hits re-wrap the PNG in a fresh `Image.memory`; Flutter's
  global image cache absorbs the decode cost but the decoded frames
  are still re-materialised on each widget build rather than reused
  as a pre-decoded `ui.Image`.

## Alternatives Considered

### Server-side rendering

Rejected: violates offline-first and zero-network principles.

### Pure-Dart port

Rejected: cost prohibitive, feature gap unacceptable.

### Returning SVG strings and rendering via `flutter_svg`

Tried first. Rejected because the SVG-data-URI round-trip dropped
inline CSS on Android WebView (API 28+), breaking hit-boxes and
label text positioning for `gantt`, `sequence`, and `journey`
diagrams. The PNG screenshot path produces pixel-identical output
across platforms at the cost of one extra decode per cache hit.
