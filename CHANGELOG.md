# Changelog

All notable user-visible changes are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/).

Internal refactors, test-only changes, and documentation updates are
kept out of this file — they belong in commit history instead.

## [Unreleased]

## [1.1.0] — 2026-04-19

First minor release after v1.0. Closes three long-standing roadmap
items — library-wide content search, pull-to-refresh on every library
source, and a dedicated Mermaid fullscreen viewer — and gets the app
out of patch-release mode.

### Added
- **Full-text content search on every library tab.** The search
  field no longer only filters filenames. Typing three or more
  characters fires a debounced, isolate-backed scan whose scope
  follows the active tab: the Recents tab scans across every
  recent document, folder source and synced repository; a folder
  tab scans only that folder; a synced-repo tab scans only that
  repository's local mirror. Hits surface under a dedicated "In
  document contents" header with the matched fragment highlighted
  in the primary-container colour and a multi-match counter. Tapping
  a result opens the viewer at the matching document — folder-source
  hits route through the platform materializer so iOS
  security-scoped bookmarks and Android SAF tree URIs still work.
  The scan runs inside a Dart `compute()` isolate with 10 MB / file
  and 2 000 files / query hard caps so a large repository cannot
  stall the UI.
- **Pull-to-refresh on every library surface.** Swiping down on the
  Recents tab re-reads the persisted recents + sources snapshot.
  Swiping down on a folder source re-enumerates the directory
  (picking up newly-added markdown files without reopening the
  drawer). Swiping down on a synced-repo tab triggers a fresh
  `RepoSyncNotifier` cycle against the stored GitHub URL; the
  indicator stays visible for the full round-trip and known SHAs
  short-circuit unchanged files so a re-sync on a settled repo is
  near-instant. An active search survives the refresh — the
  recursive walk restarts automatically so the next paint reflects
  freshly-synced files.
- **Mermaid diagram fullscreen viewer.** A new expand-icon
  affordance on every rendered diagram opens the dense diagram
  (flowchart, ER, mindmap, Gantt, etc.) in an edge-to-edge viewer
  with pinch-zoom up to 10× and free pan. The existing reset /
  recenter button carries through, gated to the same
  transform-dirty visibility as the inline view. The top chrome
  bar (close + reset) is always visible so the close button can
  never be hidden by a stray tap; the scaffold background and
  chrome buttons track the active reading theme (light / dark /
  sepia) so the diagram's own palette stays readable instead of
  being crushed against a hardcoded black surface. Popping back
  restores the exact scroll offset in the host document — the
  detour does not break the reading flow.

### Changed
- **Onboarding condensed from five pages to three.** The original
  flow interleaved a dedicated rendering-features page and a
  personalization page between welcome and the "open a folder"
  call to action, which pushed the user through four taps of
  Next/Skip before the library surfaced. The rendering callout is
  now folded into the welcome copy, the personalization page is
  dropped entirely (those settings are already discoverable in
  Settings), and the welcome / sources / default-handler trio
  lands the user in the library after two taps of Next. Copy is
  tightened to a single sentence per body. Returning users see
  the new flow exactly once on their next cold start via the
  standard onboarding-version bump.

## [1.0.2] — 2026-04-18

Second patch release after v1.0. Fixes the AirDrop / Open-In routing
regression on iOS, adds a default-handler onboarding step for Android,
and resolves an iPad crash when math appears inside a pipe table.

### Fixed
- **AirDrop and Open-In no longer land on "Page Not Found" on iOS.**
  `SceneDelegate` was forwarding every incoming `URLContext` to `super`,
  which let the Flutter engine push raw sandbox paths
  (`file:///private/var/.../*.md`) onto the `go_router` stack as if
  they were routes. File URLs are now consumed by `FileOpenChannel`
  only and never propagate to the router; non-file URLs keep the
  default path.
- **Android ACTION_VIEW intents are no longer ambiguous.** The
  manifest explicitly sets `flutter_deeplinking_enabled=false` so a
  future Flutter SDK default cannot silently revive the same
  regression on the `.md` intent handler.
- **Pipe tables containing inline math no longer crash the viewer.**
  `flutter_math_fork`'s internal `_RenderLayoutBuilderPreserveBaseline`
  deliberately throws on intrinsic-width queries, which `RenderTable`'s
  default `IntrinsicColumnWidth` triggers as soon as a cell contains
  `$\alpha$`. Each `MathView.inline` / `MathView.display` is now
  wrapped in an `_IntrinsicSafe` `RenderProxyBox` that short-circuits
  intrinsic queries so the table can size its columns from the text
  cells. `SelectionContainer.disabled` is also applied so
  `SelectionArea` no longer walks into the math render tree for
  bounding-box computation.
- **Tapping "Get started" at the end of onboarding no longer crashes.**
  The router provider used to `ref.watch(shouldShowOnboardingProvider)`,
  which tore down and rebuilt `GoRouter` mid-navigation and triggered
  the `dispose() called during notifyListeners()` assertion on
  `GoRouteInformationProvider`. The router now subscribes via
  `ref.listen` + a `refreshListenable` `ChangeNotifier`, keeping the
  router alive for the app's lifetime and only nudging the redirect
  guard to re-evaluate.
- **Router teardown order.** `GoRouter` is now disposed before the
  refresh `ChangeNotifier` so the router's listener detachment
  happens while the notifier is still live.

### Added
- **Default-handler onboarding step.** A fourth onboarding page
  explains how to make MarkdownViewer the default opener for `.md`
  files, with a platform-aware CTA that deep-links into Android's
  per-app "Open by default" settings. iOS has no equivalent screen,
  so the CTA only renders on Android. `currentOnboardingVersion` is
  bumped to 2 so returning users see the new page once.

## [1.0.1] — 2026-04-17

First patch release after v1.0.0. Bundles the navigation fixes,
release-pipeline hardening, and performance pass into a single
tag — v1.0.2 was planned and then rolled into v1.0.1 before
either intermediate tag left the development branch.

### Fixed
- **TOC drawer first tap no longer snaps the document back to
  offset 0.** The root cause was `Scrollable.ensureVisible`
  walking up through the `NestedScrollView`'s outer Scrollable
  and renegotiating the floating-SliverAppBar scroll position
  on every call, resetting the inner body's scroll position
  mid-animation. Replaced the call with a direct
  `controller.animateTo` driven by
  `RenderAbstractViewport.getOffsetToReveal(...)` so the inner
  scroll position is the only thing the viewer touches. Scroll
  and drawer dismissal now run concurrently and land together.
- **Cross-file markdown links** (`[label](other.md)` and
  `[label](../shared/types.md#section)`) now open the target
  file in a new viewer route when the file exists in the same
  source tree. Non-markdown targets and paths that would escape
  the source directory are refused by construction. Cross-file
  anchor fragments (`#section`) are forwarded through a new
  `ViewerRoute.location(path, anchor: …)` overload and consumed
  once the destination document has parsed.
- **In-document anchor links** (`[label](#slug)`) now resolve
  under four previously-failing href shapes:
  - **Case mismatches** — `[x](#Foo)` lands on a heading with
    anchor `foo`, matching GitHub's case-insensitive lookup
    behaviour.
  - **Percent-encoded characters** — `[x](#kullan%C4%B1c%C4%B1)`
    resolves to a Turkish-titled heading; `[x](#my%20head)`
    resolves to a heading with `my head` in its slug.
  - **`+` as encoded space** — `[x](#my+heading)` also decodes.
  - **Schemeless hrefs** — a renderer that strips the leading
    `#` before calling the link handler now routes through the
    anchor-resolver fallback instead of hitting the
    unsafe-scheme block.

  Every path goes through a single shared `resolveAnchor`
  helper with eleven unit tests covering the normalisation
  permutations; malformed percent escapes fall through to the
  raw comparison rather than throwing. Unresolved schemeless
  hrefs are dropped with a diagnostic log instead of
  escalating to the unsafe-scheme warning.
- **Reading-time estimate** is now computed once per document
  and cached in an `Expando` — the full-source whitespace split
  that produced the `viewerReadingTime` label used to re-run on
  every scroll tick, theme flip, and search-highlight refresh.
- **One-shot reading-position restore** no longer dispatches
  its guarded no-op method on every rebuild of the viewer's
  `data:` branch — the `_restoreAttempted` check is hoisted to
  the call site so rebuilds long after the restore already
  fired skip the method dispatch entirely.

### Added
- **Feature-tour example library** under `docs/examples/`, split
  into category folders (`01-text/`, `02-blocks/`,
  `03-navigation/`, `04-math.md`, `05-mermaid/`) so first-run
  users see every CommonMark / GFM / Mermaid / math surface the
  viewer renders and experience folder navigation in the library
  drawer. The sync "Try it" card now pre-fills this path
  (`.../docs/examples`) instead of the full `docs/` tree.

### Changed
- **Release pipeline** now builds the Android AAB and iOS IPA
  with `--obfuscate --split-debug-info=build/symbols` and
  Android's R8 / `shrinkResources` pass enabled. The resulting
  AAB is ~15–20 % smaller — a shorter download for users on
  slower networks and a smaller cold-start code-load cost on
  older devices. `flutter symbolize` rehydrates Sentry stack
  traces from the artifacts the workflow now attaches to each
  GitHub Release (`android-symbols`, `ios-symbols`, 90-day
  retention).

### Internal
- `SearchHighlightState` gained value equality so any
  downstream `updateShouldNotify` / `Selector` that we plug in
  later can short-circuit when the search state has not
  actually changed.
- `docs/standards/performance-standards.md` targets
  cross-checked against hot paths; seven items confirmed
  already-optimal (mermaid LRU cache, footnote /
  mermaid-code Expandos, scroll listener change-detect,
  search-scan isolate + debounce, `ref.watch` scoping,
  stateless parser, router builders).

## [1.0.0] — 2026-04-17

First public release. The app has been through three private beta
rounds (v0.2.0 – v0.2.2) on TestFlight and Play Console internal
tracks, a 128-finding full-codebase code review, a leak-tracker
integration pass, and a dedicated security review. All P0 / P1 items
from those passes are closed; the remaining Medium and Low items are
tracked in `docs/roadmap.md`.

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

### Security
- Markdown links now pass through a URI-scheme allow-list
  (`http`, `https`, `mailto`) before reaching `launchUrl`. A malicious
  markdown file can no longer trigger `intent://`, `tel:`, `sms:`,
  `market:`, or `file:` handlers to launch third-party apps or probe
  local files.
- GitHub sync Dio client enforces a host allow-list in the request
  interceptor — `api.github.com` and `raw.githubusercontent.com`
  only. Any other host (direct call or 3xx redirect follow-up) is
  rejected before the socket opens, which also prevents the stored
  PAT from being forwarded to an untrusted redirect target.
- GitHub sync response size caps: 5 MB per file download, 25 MB per
  discovery call (Trees API / Contents API / default-branch
  metadata). Enforced via `CancelToken` + `onReceiveProgress` so an
  oversized response is aborted mid-stream rather than buffered
  into memory.
- Native library-folder and share-intent channels refuse to load
  files larger than 10 MB. iOS pre-checks `fileSizeKey`, Android
  pre-checks `OpenableColumns.SIZE` and, for providers that omit
  it, streams with a cumulative-bytes guard that deletes any
  partial copy on abort.

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
- Library "Clear all" confirm-dialog guard is now per-widget state
  instead of a file-scope mutable flag, and is released in a
  `try/finally` so a rare `showDialog` throw cannot permanently
  disable the button.
- Sandbox-path resolution no longer throws `RangeError` when a
  persisted path matches a sandbox root exactly (previously possible
  only on unusual edge cases, but the code path is reachable because
  the matcher does accept root-equality). Initialisation also now
  guards each of the three well-known directories independently so
  an unusual platform that exposes only a subset still boots.
- Settings persistence: the logger invocation inside the persist-or-log
  error handler is now wrapped in its own `try/catch` so a torn-down
  provider container cannot swallow the original persist failure.
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

[Unreleased]: https://github.com/cemililik/markdown-viewer-mobile/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/cemililik/markdown-viewer-mobile/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/cemililik/markdown-viewer-mobile/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/cemililik/markdown-viewer-mobile/compare/v0.2.2...v1.0.0
[0.2.2]: https://github.com/cemililik/markdown-viewer-mobile/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/cemililik/markdown-viewer-mobile/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/cemililik/markdown-viewer-mobile/releases/tag/v0.2.0
