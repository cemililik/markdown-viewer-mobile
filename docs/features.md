# Features

Feature catalog grouped by area. Each feature is tagged with a release
phase; see [roadmap.md](roadmap.md) for scheduling.

## Rendering Features

### Core Markdown (MVP)

- Headings (ATX and Setext) with auto-generated anchor IDs
- Paragraphs, line breaks, horizontal rules
- Emphasis: bold, italic, strikethrough, and combinations
- Block quotes with nesting support
- Ordered, unordered, and nested lists
- Inline code and fenced code blocks
- Links (inline, reference, autolink)
- Images (relative and absolute URIs)
- Tables with alignment
- Task lists (read-only)

### Advanced Blocks (MVP)

- **Syntax-highlighted code** — 150+ languages via `re_highlight`
- **Mermaid diagrams** — WebView-rendered, sandboxed
- **LaTeX math** — inline and block via `flutter_math_fork`
- **Footnotes** — bi-directional navigation
- **Admonitions** — `!!! note`, `!!! warning`, `!!! tip`

### Enhancement (Post-MVP)

- Allow-listed embedded HTML subset
- Custom containers and callouts
- SVG inline rendering
- Diagram formats beyond mermaid

## Reading Experience Features

### Shipped (Phases 1–4)

- **Table of contents drawer** — right-side drawer listing every heading
  with proportional indent; tapping jumps with a 450 ms smooth animation
- **In-document search** — browser find-in-page style bottom bar with
  inline match highlighting (PUA sentinel approach), match counter
  (`3 / 12`), prev/next navigation, skip-code-block logic
- **Reading comfort settings** — font scale (0.85× – 1.5×), reading
  width (Comfortable / Wide / Full), line height (Compact / Standard /
  Airy); persisted to SharedPreferences
- **Sepia reading theme** — warm paper tone selectable alongside
  Light / Dark / System in Settings
- **Immersive scroll** — AppBar and FAB auto-hide on scroll down and
  reveal on scroll up
- **Keep-screen-on toggle** — prevents sleep while reading; persisted
  to Settings
- **Text selection** — long-press activates native text selection handles;
  Share action passes selected text to the system share sheet
- **In-document anchor links** — tapping `[text](#heading-id)` scrolls
  to the target heading; external `http`/`https` links open in the
  system browser
- **Footnote popup sheets** — bi-directional navigation; footnote
  definition stripped from the document body and shown in a scrollable
  `ModalBottomSheet`
- **Reading time estimate** — displayed in the AppBar subtitle
  (`≈ N min read`) based on average reading speed
- **Haptic feedback** — light impact on TOC jump, bookmark save,
  back-to-top, and in-document search next/prev
- **Reading-position bookmark** — AppBar toggle saves current scroll
  offset; first-frame restore with smooth animation; long-press opens
  Go-to / Remove menu; first-save coach mark; persisted via
  `ReadingPositionStore` (SharedPreferences)
- **Back-to-top FAB** — fades in past 200 px, animates back to top
- **Pinch-to-zoom on diagrams** — `InteractiveViewer` on every Mermaid
  block; centre/reset button fades in once transformed
- Light / Dark / System / Sepia theme
- Material 3 dynamic color (system wallpaper seed, Android 12+)

### Post-v1 Candidates

- Split-view on tablets
- Presentation / slideshow mode
- Swipe between adjacent files

## File Management Features

### Shipped (Phases 1–4)

- **Open via system file picker** — single-file picker (`.md`, `.markdown`)
- **Recent files list** — SharedPreferences-backed, LRU cap 20, time-grouped
  (Today / Yesterday / Earlier this week / Earlier), preview snippet
- **Pinned files** — long-press → Pin to top; exempt from LRU eviction
- **Folder browser** — left-side source-picker drawer; multi-root; lazy
  expansion tree in the body when a folder source is active; flat search
  across the full subtree
- **Native folder access** — iOS security-scoped bookmarks + Android SAF
  persistent URI permissions via custom method-channel bridges; dart:io
  never touches content:// URIs directly
- **Default markdown handler** — registered as system handler for
  `.md` / `.markdown` on Android (`ACTION_VIEW`, `ACTION_SEND`) and iOS
  (`CFBundleDocumentTypes`, Files app "Open in")
- **Share-as-PDF export** — renders the current document as a PDF via
  the `pdf` package; Mermaid diagrams are pre-rendered to PNG and embedded
  inline; share sheet hands the PDF to any app (AirDrop, Mail, Files, …)
- **Share selected text** — system share sheet for highlighted text passages

### Post-v1 Candidates

- Watch folder for changes
- Cloud provider integration (Google Drive, iCloud) via system pickers

## Repository Sync Features

User-initiated sync of markdown documentation from public git
repositories. See [ADR-0011](decisions/0011-network-access-policy.md) and
[ADR-0012](decisions/0012-document-sync-architecture.md).

### MVP (Phase 4.5)

- Paste a public GitHub URL and sync the entire `.md` tree
- Supported URL forms:
  - `https://github.com/{owner}/{repo}`
  - `https://github.com/{owner}/{repo}/tree/{ref}`
  - `https://github.com/{owner}/{repo}/tree/{ref}/{path}`
  - `https://github.com/{owner}/{repo}/blob/{ref}/{path}`
- Recursive directory traversal preserving original structure
- Bounded-concurrency parallel downloads
- Progress UI with cancel
- Partial-failure tolerance (commits whatever succeeded)
- Local mirror under app documents directory
- `synced_repos` library tab listing every synced repository
- Re-sync to refresh
- Delete a synced repository (files + database row)
- Optional GitHub Personal Access Token in platform secure storage
- Sync runs in a background isolate — UI stays responsive

### Post-MVP

- Additional providers: GitLab, Bitbucket, Gitea
- Generic raw-HTTP provider for arbitrary directories
- Webhook-style refresh notification (when provider supports it)
- Automatic refresh on a schedule (opt-in only)
- Conflict resolution when local files have been edited externally
- Sub-tree filters and exclusion patterns
