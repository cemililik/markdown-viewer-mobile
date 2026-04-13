# Mermaid diagram fixture

This fixture exercises every diagram type the viewer must support
plus one deliberately broken source. It is parsed by widget tests
and by the manual on-device smoke pass.

## Flowchart

```mermaid
flowchart LR
    A[Start] --> B{Decision}
    B -- yes --> C[Continue]
    B -- no --> D[Stop]
    C --> D
```

## Sequence diagram

```mermaid
sequenceDiagram
    participant U as User
    participant V as Viewer
    participant R as Renderer
    U->>V: open file
    V->>R: render(source)
    R-->>V: svg
    V-->>U: rendered diagram
```

## Class diagram

```mermaid
classDiagram
    class Document {
        +String id
        +String source
        +parse() Document
    }
    class Renderer {
        +render(code) String
    }
    Document --> Renderer
```

## State diagram

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Loading : open()
    Loading --> Ready : success
    Loading --> Failed : error
    Failed --> Idle : retry
    Ready --> [*]
```

## Entity-relationship diagram

```mermaid
erDiagram
    USER ||--o{ DOCUMENT : owns
    DOCUMENT ||--|{ BLOCK : contains
    USER {
        string id
        string name
    }
    DOCUMENT {
        string id
        string title
    }
    BLOCK {
        string id
        string kind
    }
```

## Gantt chart

```mermaid
gantt
    title Phase 1 progress
    dateFormat YYYY-MM-DD
    section Slices
    1.4 Math       :done, m14, 2026-04-09, 1d
    1.5 Admonitions:done, m15, after m14, 1d
    1.6 Mermaid    :active, m16, after m15, 1d
```

## Broken diagram (regression guard)

The block below is intentionally invalid. The viewer must render
the inline error placeholder for it instead of crashing the rest
of the document — every following block must continue to render.

```mermaid
flowchart LR
    A -->
```

## Trailing prose

A paragraph after the broken diagram. If you can read this in the
running app, the error path stayed inline and did not poison the
document tree.
