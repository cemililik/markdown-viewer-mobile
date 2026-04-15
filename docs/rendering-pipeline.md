# Rendering Pipeline

End-to-end flow from a `.md` file on disk to pixels on screen.

## Stages

The full pipeline from disk bytes to painted pixels:

```mermaid
flowchart LR
    A[Bytes on disk] --> B[Decode UTF-8]
    B --> C[AST Parse<br/>markdown package]
    C --> D[AST Transform<br/>custom passes]
    D --> E[Widget Build<br/>markdown_widget]
    E --> F[Paint<br/>Skia / Impeller]
```

### Stage 1 — Decode

- Read file as bytes via `File.readAsBytes()`
- Detect BOM; fall back to UTF-8
- For documents larger than 200KB, perform remaining stages in an isolate
  via `compute()`

### Stage 2 — AST Parse

- Use the official Dart `markdown` package with a configured `Document`
- Enable extensions: GFM, tables, footnotes, inline-HTML (escaped)
- Register custom block syntaxes:
  - `MermaidBlockSyntax` — detects ` ```mermaid ` fenced blocks
  - `MathBlockSyntax` — detects `$$...$$` blocks
  - `AlertBlockSyntax` (built-in) — detects `> [!NOTE|TIP|IMPORTANT|WARNING|CAUTION]`
    GitHub-style blockquote alerts
- Output: `List<md.Node>`

### Stage 3 — AST Transform

Walk the AST to:

- Resolve relative image and link paths to absolute URIs against the
  document's base directory
- Build a `TableOfContents` from heading nodes, each stamped with its
  enclosing top-level block index for pixel-perfect `Scrollable.ensureVisible`
  jumps from the TOC drawer
- Collect and strip footnote definitions; store them for pop-up display
- Normalize code-block language identifiers

### Stage 4 — Widget Build

Feed the AST into `markdown_widget` with a custom `MarkdownGenerator`.
Register custom node generators for:

- `code` → syntax-highlighted block via `re_highlight`
- `mermaid` → `MermaidBlockWidget`
- `math` → `flutter_math_fork` widget
- `admonition` → themed container

Images flow through `Image.file` / `Image.network` with disk-backed cache.

### Stage 5 — Paint

- Flutter's standard rendering pipeline
- Mermaid, math, and code blocks paint their own sub-trees

## Mermaid Rendering Sub-Pipeline

Mermaid is rendered via a sandboxed `HeadlessInAppWebView`. The output
is a PNG screenshot taken from the WKWebView/WebView surface, not an SVG
string — this avoids CSS-compatibility problems that `flutter_svg` has
with mermaid's generated SVG output.

```mermaid
sequenceDiagram
    participant W as MermaidBlock<br/>widget
    participant R as MermaidRenderer
    participant C as PNG LRU Cache<br/>sha256(init+src)
    participant V as HeadlessInAppWebView<br/>(sandboxed)

    W->>R: render(initDirective, code)
    R->>C: lookup(sha256(init+code))
    alt cache hit
        C-->>R: PNG bytes + dimensions
    else cache miss
        R->>V: evaluateJavascript<br/>mermaid.render(id, code)
        V->>V: inject themeVariables<br/>from ColorScheme
        V->>V: controller.takeScreenshot()
        V-->>R: PNG bytes + intrinsic size
        R->>C: store(sha256, PNG + size)
    end
    R-->>W: PNG bytes + dimensions
    W->>W: Image.memory(bytes)<br/>inside InteractiveViewer
```

Strategy:

1. On app start, pre-warm a single hidden `HeadlessInAppWebView` with
   the bundled `mermaid.min.js` asset and a CSP `<meta>` tag
2. Inject Material 3 `ColorScheme` colours as `themeVariables` so every
   diagram type reads as if drawn by the app itself in both themes
3. Call `mermaid.render(id, code)` via `evaluateJavascript`; capture the
   rendered SVG inside the WebView using `controller.takeScreenshot()`
4. Return PNG bytes + intrinsic dimensions; render as `Image.memory`
   inside an `InteractiveViewer` (pan + pinch + animated reset button)
5. Cache PNG by `sha256(initDirective + source)` in a bounded in-memory
   LRU (`MermaidLruCache`). Cache key includes the init directive so a
   user-authored `%%{init: …}%%` directive generates a distinct entry

**Security**: the WebView has no network access (`blockNetworkLoads`),
no local file access, and a single `mermaidResult` JS bridge handler.
See [standards/security-standards.md](standards/security-standards.md).

## Code Highlighting Sub-Pipeline

1. Detect language from the fenced block info string
2. Look up the grammar in the `re_highlight` language registry
3. Tokenize the source; map tokens to `TextSpan`s with theme colors
4. Theme colors come from the active app theme (light / dark)
5. Fallback: plain monospace rendering if the language is unknown

## Math Rendering Sub-Pipeline

- Inline: `$...$` → `Math.tex(...)` inside a `WidgetSpan`
- Block: `$$...$$` → centered `Math.tex(...)` with horizontal scroll overflow

## Performance Budgets

| Stage | Target | Reference device |
|-------|--------|-----------------|
| Decode + Parse (1MB) | < 200ms | Pixel 6a |
| Widget Build (1MB) | < 150ms | Pixel 6a |
| Mermaid render (typical) | < 800ms | iPhone 12 |
| Code highlight (1k lines) | < 50ms | Pixel 6a |

Exceeding any budget is a regression and must fail the CI performance
suite — see
[standards/performance-standards.md](standards/performance-standards.md).
