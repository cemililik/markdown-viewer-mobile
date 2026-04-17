# Mermaid — pie charts

Pie charts are a quick way to show relative proportions — useful
for "how is this budget split?" storytelling where exact numbers
matter less than the distribution.

## Build artifact size

```mermaid
pie showData
    title Release AAB composition (v1.0.2 — ~60 MB)
    "libflutter.so" : 33
    "libapp.so (our Dart)" : 32
    "Obfuscation symbols (not shipped)" : 22
    "classes.dex (R8-stripped)" : 7
    "mermaid.min.js" : 3
    "libsqlite3.so" : 3
```

## Test distribution

```mermaid
pie
    title 362 tests by category
    "Unit tests" : 180
    "Widget tests" : 122
    "Golden tests" : 35
    "A11y tests" : 25
```

## Performance budget allocation

```mermaid
pie
    title Viewer frame budget (16.7 ms target)
    "Layout" : 4
    "Paint" : 3
    "Raster" : 5
    "Dart work" : 3
    "Headroom" : 2
```

## Phase 5 work breakdown

```mermaid
pie
    title v1.0 hardening split
    "Code review fixes" : 45
    "Security review fixes" : 20
    "Performance pass" : 12
    "Documentation" : 15
    "Release tooling" : 8
```
