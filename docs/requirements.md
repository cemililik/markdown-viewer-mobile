# Requirements

Requirements use `FR-NNN` (functional) and `NFR-NNN` (non-functional)
identifiers. Each requirement has a priority: **MUST**, **SHOULD**, or **MAY**.

## Functional Requirements

### File Access

- **FR-001** (MUST) Open `.md` / `.markdown` files from device storage
- **FR-002** (MUST) Open files shared from other apps via share intent
- **FR-003** (MUST) Register as a handler for markdown file types
- **FR-004** (SHOULD) Show recent files history
- **FR-005** (SHOULD) Allow favoriting / pinning files
- **FR-006** (MAY) Folder-level browsing with a file tree

### Rendering

- **FR-010** (MUST) Render the full CommonMark 0.30 specification
- **FR-011** (MUST) Render GitHub Flavored Markdown extensions
- **FR-012** (MUST) Render fenced code blocks with syntax highlighting
- **FR-013** (MUST) Render tables with horizontal scroll on overflow
- **FR-014** (MUST) Render mermaid diagrams (flowchart, sequence, class,
  state, ER, gantt, pie)
- **FR-015** (MUST) Render LaTeX math — inline `$...$` and block `$$...$$`
- **FR-016** (MUST) Render task lists (read-only checkboxes)
- **FR-017** (SHOULD) Render footnotes with bi-directional navigation
- **FR-018** (SHOULD) Render admonition blocks (note, warning, tip)
- **FR-019** (SHOULD) Resolve relative image and link references
- **FR-020** (MAY) Render an allow-listed subset of embedded HTML

### Navigation

- **FR-030** (MUST) Table of contents drawer
- **FR-031** (MUST) Tap heading in TOC to jump in the document
- **FR-032** (SHOULD) In-document search with match highlighting
- **FR-033** (SHOULD) Back / forward navigation history
- **FR-034** (MAY) Reading progress persistence per file

### Customization

- **FR-040** (MUST) Light / Dark / System theme modes
- **FR-041** (MUST) Adjustable font size
- **FR-042** (SHOULD) Font family selection (sans, serif, mono)
- **FR-043** (SHOULD) Reading width preference (narrow / wide)
- **FR-044** (MAY) Custom theme tokens

### Sharing & Export

- **FR-050** (SHOULD) Share rendered view as PDF
- **FR-051** (SHOULD) Share source text to other apps
- **FR-052** (MAY) Copy a rendered block as an image

### Repository Sync

See [ADR-0011](decisions/0011-network-access-policy.md) and
[ADR-0012](decisions/0012-document-sync-architecture.md).

- **FR-060** (MUST) Accept a public GitHub URL of the form
  `https://github.com/{owner}/{repo}[/tree/{ref}[/{path}]]` and parse it
  into a typed locator
- **FR-061** (MUST) Discover all `.md` / `.markdown` files at and below
  the requested path on the requested ref
- **FR-062** (MUST) Download discovered files to local storage,
  preserving the original directory structure
- **FR-063** (MUST) Track every synced repository (provider, owner, repo,
  ref, sub-path, last sync time, file count, status)
- **FR-064** (MUST) Show sync progress with cancel support
- **FR-065** (MUST) Commit partial results when individual files fail
- **FR-066** (MUST) Allow re-syncing an existing entry to refresh content
- **FR-067** (SHOULD) Allow the user to delete a synced repository,
  including its local files
- **FR-068** (SHOULD) Optional GitHub Personal Access Token stored in
  platform secure storage to raise the rate limit
- **FR-069** (MAY) Detect remotely-deleted files on refresh and remove
  the local copies

## Non-Functional Requirements

### Performance

- **NFR-001** (MUST) Cold start to first frame < 1.5s on mid-range devices
- **NFR-002** (MUST) Parse and render a 1MB document in < 500ms
- **NFR-003** (MUST) Sustain 60fps scrolling on 10k-line documents
- **NFR-004** (SHOULD) Mermaid rendering < 1s for typical diagrams
- **NFR-005** (SHOULD) Memory footprint < 150MB for typical documents

### Reliability

- **NFR-010** (MUST) No crashes on malformed markdown input
- **NFR-011** (MUST) Graceful degradation when a block fails to render
- **NFR-012** (MUST) No data loss on app backgrounding or process death

### Usability & Accessibility

- **NFR-020** (MUST) Full VoiceOver / TalkBack support
- **NFR-021** (MUST) Minimum 44×44 pt / 48×48 dp touch targets
- **NFR-022** (MUST) Respect system font-size accessibility settings
- **NFR-023** (SHOULD) WCAG 2.1 AA color contrast on all themes

### Security & Privacy

- **NFR-030** (MUST) No network calls unless explicitly user-initiated
  via the repo-sync feature
- **NFR-031** (MUST) Zero telemetry, zero analytics, zero background
  network activity
- **NFR-032** (MUST) Sandbox all WebView contexts with no network access
- **NFR-033** (MUST) Sanitize embedded HTML to prevent XSS
- **NFR-034** (MUST) HTTP requests issued only by the `repo_sync` feature
  through the single shared client
- **NFR-035** (MUST) Personal Access Tokens stored in platform secure
  storage (`flutter_secure_storage`), never in shared preferences

### Portability

- **NFR-040** (MUST) Support iOS 14+ and Android 8.0 (API 26)+
- **NFR-041** (MUST) Support phone and tablet form factors
- **NFR-042** (SHOULD) Support portrait and landscape orientations

### Maintainability

- **NFR-050** (MUST) ≥ 80% overall line coverage; ≥ 95% on domain layer
- **NFR-051** (MUST) Zero `dart analyze` warnings in CI
- **NFR-052** (MUST) All architectural decisions captured as ADRs
