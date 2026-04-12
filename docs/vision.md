# Vision

## Problem Statement

Reading `.md` files on mobile devices today is a fragmented experience:

- File managers display raw markdown source
- Cloud-synced documentation doesn't render mermaid diagrams, math, or
  advanced code blocks
- Existing mobile markdown apps are either heavy editors or limited readers
- Developers reviewing documentation on the go lack a focused preview tool

## Project Vision

Build the **best mobile reading experience** for markdown documents — a
focused, fast, offline-first preview tool that renders the full CommonMark +
GFM feature set plus advanced blocks (mermaid, math, syntax-highlighted code)
with native performance and mobile-first ergonomics.

## Target Users

- **Developers** reviewing project docs, READMEs, and ADRs on mobile
- **Technical writers** proofing content away from the desk
- **Students and researchers** reading lecture notes or papers
- **Knowledge workers** using markdown-based note systems (Obsidian, Logseq)

## Value Propositions

1. **Complete rendering** — mermaid, math, code, tables, footnotes, task lists
2. **Offline-first reading** — no network required to read local files;
   the network is only touched when the user explicitly syncs from a
   remote source (see [ADR-0011](decisions/0011-network-access-policy.md))
3. **Bring your own docs** — sync entire documentation trees from public
   git repositories with one URL, then read offline
4. **Mobile-first UX** — designed for one-handed reading, gestures, dark mode
5. **Native performance** — 60fps scrolling, fast cold-start, small binary
6. **Privacy-respecting** — zero telemetry, no background traffic, no
   account system

## Success Metrics

- Opens a 1MB markdown file in < 500ms on mid-range devices
- Renders mermaid diagrams in < 1s
- 60fps scrolling on documents up to 10k lines
- < 20MB install size
- Zero crashes per 1k sessions

## Non-Goals (v1)

- Markdown *editing* — we are a reader, not an editor
- User accounts or any server-side state
- Collaborative features
- Telemetry, analytics, or background network activity
- Desktop (macOS, Windows, Linux) or web clients
- HarmonyOS native support (deferred; see
  [decisions/0009-platform-scope.md](decisions/0009-platform-scope.md))
- Sync providers other than GitHub for v1 (GitLab, Bitbucket deferred —
  see [ADR-0012](decisions/0012-document-sync-architecture.md))
