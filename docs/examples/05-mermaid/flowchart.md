# Mermaid — flowcharts

Flowcharts visualise processes, state transitions, and control flow.
The viewer renders every mermaid block inside a sandboxed WebView and
caches the result per-diagram so re-scrolling a document does not
re-render.

## Top-to-bottom

```mermaid
flowchart TB
    A[Start] --> B{Decision?}
    B -->|Yes| C[Do the thing]
    B -->|No| D[Skip it]
    C --> E[End]
    D --> E
```

## Left-to-right

```mermaid
flowchart LR
    A[Open file] --> B[Parse markdown]
    B --> C[Build widget tree]
    C --> D[Render]
    D --> E[Reader reads]
```

## Node shapes

```mermaid
flowchart LR
    A[Rectangle] --> B(Rounded)
    B --> C([Stadium])
    C --> D[[Subroutine]]
    D --> E[(Cylinder)]
    E --> F((Circle))
    F --> G{Diamond}
    G --> H{{Hexagon}}
    H --> I[/Parallelogram/]
    I --> J[\Reverse parallelogram\]
    J --> K[/Trapezoid\]
    K --> L[\Reverse trapezoid/]
```

## Edge types

```mermaid
flowchart LR
    A -->|arrow with label| B
    B --- C
    C -.->|dotted| D
    D ==>|thick| E
    E --o F
    F --x G
```

## Subgraphs

```mermaid
flowchart LR
    subgraph Source["Source markdown"]
        S1[.md file] --> S2[parser]
    end

    subgraph Render["Render pipeline"]
        R1[blocks] --> R2[widgets] --> R3[column]
    end

    subgraph Display["Display"]
        D1[scroll view]
    end

    S2 --> R1
    R3 --> D1
```

## With styling

```mermaid
flowchart LR
    A[User taps link] --> B{Href starts with #?}
    B -->|Yes| C[resolveAnchor]
    B -->|No| D{Has scheme?}
    C --> E[Scroll to heading]
    D -->|No| F[resolveRelativeDocument]
    D -->|Yes http/https/mailto| G[launchUrl]
    D -->|Yes, other| H[Block]
    F --> I{File exists?}
    I -->|Yes| J[push ViewerRoute]
    I -->|No| K[Drop with log]

    classDef good fill:#c8e6c9,stroke:#2e7d32,color:#000
    classDef bad fill:#ffcdd2,stroke:#c62828,color:#000
    class E,G,J good
    class H,K bad
```
