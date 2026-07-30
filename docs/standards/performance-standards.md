# Performance Standards

## Budgets

| Metric | Budget | Reference device |
|--------|--------|------------------|
| Cold start to first frame | < 1.5s | Pixel 6a |
| Open + first-render 1MB doc | < 500ms | Pixel 6a |
| Decode + parse 1MB doc | < 200ms | Pixel 6a |
| Build 1MB document widget tree | < 150ms | Pixel 6a |
| Scroll 10k-line doc | p95 frame time ≤ 16.67ms | Pixel 6a |
| Mermaid prewarm + typical first render | < 800ms | iPhone 12 |
| Code highlight (1k lines) | < 50ms | Pixel 6a |
| Search 500 markdown files | < 200ms | Pixel 6a |
| Install size | < 20MB | Release build |
| RSS memory (typical doc) | < 150MB | Pixel 6a |

CI fails when an enforced metric exceeds either its absolute budget or its
versioned fixed-profile baseline by more than 10%. A budget increase or
baseline regression requires a dedicated justification and approval by two
reviewers.

## Profiling

- Use Flutter DevTools for all profiling
- Use Flutter profile mode for automated measurements and release mode for
  final reference-device profiling; never use debug timings
- Reproducible benchmarks live in `integration_test/benchmark/`

## Rules

### Isolates

- CPU-heavy work (parsing > 200KB, highlighting > 2k lines) **must**
  run via `compute()`
- Long-lived isolates via `Isolate.spawn` for the mermaid render queue

### Allocations

- No `const`-eligible widgets built as non-const
- Cache lists and maps computed in selectors
- Use `ListView.builder`, never `ListView(children: ...)` for dynamic lists

### Images

- Cap image decode size to display size via `cacheWidth` / `cacheHeight`
- Use `precacheImage` for above-the-fold assets

### Rebuilds

- Use Riverpod `select` to narrow rebuild scope
- Avoid rebuilding the entire document on scroll or selection change

### Startup

- Defer non-critical work until after first frame via
  `SchedulerBinding.addPostFrameCallback`
- Lazy-load features not on the initial route
- Pre-warm the mermaid WebView in the background after first paint

## Regression Testing

- `integration_test/benchmark/` runs in CI on every PR against `main`
- One warm-up and five measured repetitions are required
- Latency gates use the median; frame-time gates use the 95th percentile
- Benchmarks fail on an absolute breach or a regression above 10%
- The fixed profile, raw results, comparison report, and timeline summaries
  are retained for 90 days
- Baselines are versioned and may change only in a dedicated reviewed commit

See
[ADR-0026](../decisions/0026-risk-scoped-integration-and-performance-gates.md)
for the fixed profile, baseline provenance, and fail-closed schema.

## Anti-Patterns

- `setState` in a scroll listener
- Rebuilding ancestors from a leaf
- Synchronous `File.readAsStringSync`
- `Opacity` widget for static transparency (use color alpha instead)
- Expensive layout passes triggered every frame
