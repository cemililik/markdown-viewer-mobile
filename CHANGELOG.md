# Changelog

All notable user-visible changes are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/).

Internal refactors, test-only changes, and documentation updates are
kept out of this file — they belong in commit history instead.

## [Unreleased]

### Added
- "Try it" card on the sync screen that pre-fills the MarkdownViewer
  docs repo URL so a first-time user can explore the feature with a
  single tap.
- "Synced repositories" hub on the sync screen — every previously
  synced repo is listed with re-sync / open-in-library shortcuts,
  turning the screen into a sync-management hub rather than just an
  add-new-repo form.
- Trailing refresh icon on synced-repo drawer tiles for one-tap
  re-sync without a long-press.
- Accessibility statement page on the public site
  (`cemililik.github.io/markdown-viewer-mobile/accessibility.html`)
  covering WCAG 2.1 AA commitment, screen reader support, visual and
  motor accessibility, and feedback channels. Available in English
  and Turkish.
- GitHub Discussions enabled on the repository, with welcome / feature-
  request template / Q&A guide discussions.

### Changed
- Onboarding now respects the platform "Reduce Motion" preference —
  the pulsing hero, floating chips, gradient cross-fade, and entrance
  tween all collapse to static state when accessibility animations are
  disabled.
- Onboarding screen is now fully screen-reader friendly: skip button,
  page indicator, and CTA announce localized labels; decorative
  floating chips are hidden from the accessibility tree.
- GitHub sync: single-file `/blob/` URLs now participate in SHA-based
  incremental re-sync instead of re-downloading the file on every run.
- GitHub sync: cancelling mid-download no longer wipes database
  metadata, so the next re-sync still skips unchanged files on disk.
- GitHub sync: timeouts and authentication errors now surface as
  dedicated messages ("no network connection", "invalid token",
  "access denied — repository may be private") instead of generic
  "HTTP null" / "HTTP 401".

### Fixed
- Router lifecycle: `routerProvider` now disposes the underlying
  `GoRouter` (delegate, parser, information provider) when the
  `ProviderScope` tears down. Caught by `leak_tracker`; visible in
  production as a small leak each time the app's container would
  rebuild.
- Mermaid diagrams in a document no longer re-render on every scroll
  tick — the renderer cache is now wired end-to-end and hits for
  previously seen diagrams.
- Mermaid diagrams: `clearCache` is enforced on the sandbox WebView.
- PDF export preserves Windows / CRLF-ended files correctly; headings
  and table cells no longer show stray `\r` characters.
- Math blocks: an unclosed `$$` fence no longer swallows the rest of
  the document — the implicit body closes on the next heading, fence,
  horizontal rule, or blank line.
- Library preview snippets keep underscores in identifiers
  (`snake_case` no longer becomes `snakecase`) and no longer filter
  short prose lines starting with `--`.
- iOS folder access: security-scoped bookmarks are now created and
  resolved with the correct `.withSecurityScope` flag, so picked
  folders keep working after an app restart. Stale bookmarks are
  refreshed automatically.
- Android folder access: `listDirectory` and `readFileBytes` now
  reject URIs that fall outside the picked tree (confused-deputy fix).
- Android file-open: `file://` URIs are sandboxed to the app cache
  directory; cache filenames are sanitised to prevent path traversal.
- Sepia theme's tonal surface elevation works again (Material 3
  `surfaceTint` was missing).
- Crash reporting toggle now awaits Sentry init/close before returning
  and surfaces errors through a snackbar instead of silently swallowing
  them; the "reset settings" flow also disables crash reporting.

## [0.2.2] — 2026-04-15

### Fixed
- Release pipeline: iOS Xcode SDK pinned to `latest-stable` via
  `maxim-lobanov/setup-xcode@v1.7.0` so App Store Connect accepts
  builds (ITMS-90725 hard deadline).

## [0.2.1] — 2026-04-15

### Added
- Sentry crash reporting (ADR-0014). Default off; user opts in via
  **Settings > Send crash reports**. Crash reports never include
  document content, file paths, or GitHub PATs.
- First-run onboarding: four-page animated walkthrough shown on a
  fresh install and again when the content version bumps. Debug-only
  "Show onboarding again" affordance in Settings.
- `Try it` + recent-syncs sync-screen UX as described above — landed
  on this release's mid-cycle build.

### Changed
- System locale resolution: Turkish devices now correctly land on the
  Turkish app locale even when the OS preferred-locale list contains
  unsupported entries ahead of Turkish. Replaces Flutter's default
  "fallback to first preferred" behaviour.
- Structured release logging: `LogfmtPrinter` at `Level.warning` in
  release mode, `PrettyPrinter` at `Level.debug` in debug.

### Fixed
- iOS TestFlight upload: replaced
  `apple-actions/upload-testflight-build` with
  `xcrun altool --upload-app` because the Ruby-based action surfaces
  every failure as the opaque `OSStatus error -10814` on arm64 runners.
- ITMS-90683 App Store compliance: added
  `NSPhotoLibraryUsageDescription` (Flutter's `printing` / `share_plus`
  plugins link PhotoKit) and preemptive
  `ITSAppUsesNonExemptEncryption = false`.

## [0.2.0] — 2026-04-14

### Added
- First-time beta release to TestFlight + Google Play internal track.

### Fixed
- iOS signing: `CODE_SIGN_IDENTITY` set without the `[sdk=iphoneos*]`
  qualifier because that form evaluates inconsistently across archive
  phases.

[Unreleased]: https://github.com/cemililik/markdown-viewer-mobile/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/cemililik/markdown-viewer-mobile/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/cemililik/markdown-viewer-mobile/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/cemililik/markdown-viewer-mobile/releases/tag/v0.2.0
