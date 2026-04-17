# Mermaid — quadrant charts

Quadrant charts plot items on two axes, categorising them into four
quadrants — classic for prioritisation (impact vs. effort,
importance vs. urgency) and risk matrices.

## Impact / effort for v1.1 backlog

```mermaid
quadrantChart
    title v1.1 backlog — impact vs. effort
    x-axis Low Effort --> High Effort
    y-axis Low Impact --> High Impact

    quadrant-1 Do First
    quadrant-2 Schedule
    quadrant-3 Drop
    quadrant-4 Delegate

    Share-intent import: [0.3, 0.8]
    Swipe between files: [0.4, 0.75]
    Drift schema migration: [0.5, 0.6]
    Memory leak profiling: [0.7, 0.55]
    A11y end-to-end audit: [0.8, 0.85]
    Sentry perf tracing: [0.5, 0.45]
    CI coverage floor: [0.35, 0.3]
    Additional sync providers: [0.9, 0.7]
```

## Security findings triage

```mermaid
quadrantChart
    title Security review findings — severity vs. likelihood
    x-axis Low Likelihood --> High Likelihood
    y-axis Low Severity --> High Severity

    quadrant-1 "Fix now"
    quadrant-2 "Plan + announce"
    quadrant-3 "Accept"
    quadrant-4 "Monitor"

    H-1 URL scheme allow-list: [0.8, 0.75]
    M-1 Host allow-list: [0.5, 0.6]
    M-2 Response size caps: [0.45, 0.55]
    M-3 Redirect token: [0.3, 0.65]
    M-5 iOS read cap: [0.4, 0.5]
    M-7 Android read cap: [0.4, 0.5]
    M-8 Share-intent cap: [0.45, 0.5]
    L-1 Debug log paths: [0.15, 0.2]
    L-3 R8 minification: [0.25, 0.3]
    L-7 Files app visibility: [0.15, 0.25]
```

## Feature reception grid

```mermaid
quadrantChart
    title User feedback on v1.0 features
    x-axis Low Adoption --> High Adoption
    y-axis Low Satisfaction --> High Satisfaction

    Mermaid rendering: [0.8, 0.9]
    LaTeX math: [0.5, 0.85]
    GitHub sync: [0.75, 0.8]
    PDF export: [0.4, 0.7]
    In-doc search: [0.6, 0.65]
    TOC drawer: [0.85, 0.75]
    Sepia theme: [0.3, 0.6]
    Reading bookmark: [0.65, 0.7]
    Onboarding: [0.95, 0.55]
    Keep screen on: [0.25, 0.45]
```
