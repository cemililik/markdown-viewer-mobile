# Performance Standards

## Budgets

| Metric | Budget | Reference device |
|--------|--------|------------------|
| Cold start to first frame | < 1.5s | Pixel 6a |
| Parse + render 1MB doc | < 500ms | Pixel 6a |
| Scroll FPS (10k-line doc) | ≥ 60fps sustained | Pixel 6a |
| Mermaid render (typical) | < 800ms | iPhone 12 |
| Code highlight (1k lines) | < 50ms | Pixel 6a |
| Install size | < 20MB | Release build |
| RSS memory (typical doc) | < 150MB | Pixel 6a |

Any PR that regresses a budget by more than 10% must be justified and
approved by two reviewers.

## Profiling

- Use Flutter DevTools for all profiling
- Profile **release builds**, never debug
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
- Benchmarks fail CI when any budget regresses by more than 10%
- Historical data is stored for trend analysis

## Anti-Patterns

- `setState` in a scroll listener
- Rebuilding ancestors from a leaf
- Synchronous `File.readAsStringSync`
- `Opacity` widget for static transparency (use color alpha instead)
- Expensive layout passes triggered every frame
