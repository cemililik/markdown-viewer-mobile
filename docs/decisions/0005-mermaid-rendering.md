# ADR-0005: Mermaid via sandboxed InAppWebView

- **Status**: Accepted
- **Date**: 2026-04-12

## Context

Mermaid is defined as a JavaScript library. There is no pure-Dart port
with feature parity. Options:

1. Bundle `mermaid.min.js` and render via a sandboxed WebView
2. Render server-side (requires network, violates offline-first)
3. Re-implement a subset in Dart (unbounded cost, partial support)
4. Render to image at build time (does not work for user documents)

## Decision

- Bundle **`mermaid.min.js`** as an asset
- Use **`flutter_inappwebview`** (≥ 6) to create a single pre-warmed,
  sandboxed WebView at app start
- Expose a `MermaidRenderer` service that queues render requests and
  returns SVG strings
- Render returned SVG via `flutter_svg` inline
- Cache rendered SVG by `sha256(source)` in an in-memory LRU

## Consequences

### Positive

- Full mermaid feature parity with upstream
- Offline-first — no network required
- Sandbox gives us security guarantees (see security standards)
- Inline SVG renders natively and scales crisply

### Negative

- WebView adds ~5MB to the binary
- First mermaid render pays a WebView warmup cost
- Upgrading mermaid requires bundling a new JS file

## Alternatives Considered

### Server-side rendering

Rejected: violates offline-first and zero-network principles.

### Pure-Dart port

Rejected: cost prohibitive, feature gap unacceptable.
