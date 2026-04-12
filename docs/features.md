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

### MVP

- Table of contents drawer
- In-document search
- Adjustable font size and family
- Light / Dark / System theme
- Pinch-to-zoom on diagrams and images

### Post-MVP

- Reading progress per file
- Bookmarks within a file
- Split-view on tablets
- Presentation / slideshow mode

## File Management Features

### MVP

- Open via system file picker
- Recent files list (drift-backed)
- Share-intent import
- Default markdown handler registration

### Post-MVP

- Folder browsing
- Watch folder for changes
- Cloud provider integration via system pickers

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
