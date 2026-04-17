# Mermaid — mindmaps

Mindmaps branch outward from a single root topic. Indentation
determines depth; syntax is minimal (just nested topic names).

## Feature overview

```mermaid
mindmap
  root((MarkdownViewer))
    Rendering
      CommonMark
      GFM
        Tables
        Task lists
        Footnotes
        Strikethrough
      Mermaid
        Flowchart
        Sequence
        [Class diagram]
        [State diagram]
        ER
        Gantt
        Pie
        Journey
        [Mindmap]
        Timeline
        [Git graph]
        [Quadrant]
      LaTeX math
        Inline
        Block
      Admonitions
        NOTE
        TIP
        IMPORTANT
        WARNING
        CAUTION
    Reading UX
      Themes
        Light
        Dark
        Sepia
        Dynamic color
      Adjustments
        Font scale
        Reading width
        Line height
      Controls
        TOC drawer
        In-doc search
        Reading position
        Keep screen on
    Sources
      Recents
      Local folders
      Synced GitHub repos
      Share-intent / file open
    Export
      PDF with mermaid
      Raw markdown share
```

## Architecture layers

```mermaid
mindmap
  root((Architecture))
    Domain
      Entities
      Ports
        SettingsStore
        ConsentStore
        NativeLibraryFoldersChannel
        FolderFileMaterializer
    Application
      Providers
      Use cases
      Controllers (Notifier)
      Markdown extensions
    Data
      Repository impls
      Drift DB
      SAF / Bookmarks
      Mermaid runtime
      PAT store
    Presentation
      Screens
      Widgets
      A11y semantics
      Themes
```

## Quality gates

```mermaid
mindmap
  root((Shipping gates))
    Static
      dart format
      flutter analyze
      Custom lints (off by default)
    Tests
      Unit
      Widget
      Golden
      A11y
      leak_tracker
    Review
      Code review
        P0 → P3
      Security review
        H / M / L / I
      Performance audit
    Release
      Tag-triggered CI
      Obfuscation + R8
      Sentry symbolicate
      Store metadata pack
```
