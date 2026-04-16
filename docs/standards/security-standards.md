# Security Standards

## Threat Model (v1)

- The app reads local files the user has explicitly chosen
- The app makes network calls **only** when the user explicitly initiates
  a sync from the repo-sync feature (see
  [ADR-0011](../decisions/0011-network-access-policy.md))
- Primary risks:
  1. Malicious markdown triggering XSS in the mermaid WebView
  2. Malicious file paths escaping the document sandbox
  3. Malicious content fetched from a remote repo writing outside the
     intended mirror directory (path traversal)
  4. Hostile or compromised remote responses (HTML masquerading as `.md`,
     oversized payloads, redirect loops)
  5. Malicious code in fenced blocks being misinterpreted as executable

## WebView Rules

The mermaid WebView **must** be configured with:

- `javaScriptEnabled: true` (required by mermaid)
- `allowFileAccess: false`
- `allowFileAccessFromFileURLs: false`
- `allowUniversalAccessFromFileURLs: false`
- `clearCache: true` on init
- `blockNetworkLoads: true`
- No cookies, no local storage, no IndexedDB
- CSP meta tag: `default-src 'none'; script-src 'unsafe-inline' 'self'`
- Only two entry points: `mermaid.render(id, code)` and the result callback
- No JavaScript bridge exposing native APIs beyond the result channel

Mermaid source is treated as **untrusted input** even when the file is local.

## File System Rules

- Honor scoped storage on Android 10+
- Use `file_picker` or share intents — never construct arbitrary paths
- Never read outside the document directory tree
- Resolve relative image paths with normalization that rejects `..`
  traversal outside the base directory
- Synced repo files are written **only** under
  `<app-documents>/synced_repos/<provider>/<owner>/<repo>/<ref>/`. Reject
  any remote path containing `..`, absolute components, or characters
  that resolve outside this directory after normalization.

## Network Rules

Network access is allowed only for the `repo_sync` feature and the
consent-gated Sentry crash reporter, subject to all of:

- All HTTP requests go through the **single shared `dio` client** in
  `repo_sync` — no other feature creates HTTP clients
- The client enforces an allow-list of hosts: `api.github.com`,
  `raw.githubusercontent.com` for v1
- Every request has a timeout (connect: 10s, total: 60s)
- Every response is size-capped (per file: 5MB; per discovery call: 25MB)
- Redirects are followed only within the host allow-list, max 5 hops
- TLS verification is **never** disabled
- A short, identifiable User-Agent is sent (no PII, no device fingerprint)
- No cookies stored, no session resumption
- No automatic retry on 4xx — only on transient 5xx with bounded backoff
- Network requests are gated behind explicit user action (tap "Sync" or
  "Refresh") and never fired from app start, navigation, or scroll —
  except Sentry, which sends crash reports only when the user has opted
  in via Settings (default: off); allowed host: `*.ingest.sentry.io`
  (see [ADR-0014](../decisions/0014-logging-and-observability.md))
- Any failure surfaces as a typed `Failure` and logs the basename of the
  affected resource only

## Input Handling

- Treat all markdown input as untrusted
- Strip or escape raw HTML by default
- When HTML support lands (post-v1), use an allow-list sanitizer

## Secrets

- No API keys, tokens, or credentials in source
- `.env` files are gitignored
- Any accidentally committed secret triggers immediate rotation
- User-supplied tokens (e.g. GitHub Personal Access Token for repo sync)
  are stored **only** in `flutter_secure_storage`, never in
  `shared_preferences`, drift, or app documents
- Tokens are scoped to the minimum permission set (`public_repo`)
- Tokens are never logged, never sent to any host outside the network
  allow-list, and never serialized into crash reports

## Dependencies

- `pub outdated` reviewed monthly
- Security advisories tracked via Dependabot
- New dependencies require an architectural review and an ADR if they
  expand the attack surface

## Supply Chain (CI and Build Tooling)

The CI pipeline and release toolchain are treated as part of the attack
surface. Rules:

- **Pin every third-party GitHub Action to a full-length commit SHA**,
  with a trailing comment identifying the release (e.g.
  `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1`).
  Tags are mutable; SHAs are immutable. Bumping an action is an explicit
  diff review.
- **Never use `uses: org/repo@main`** or any other branch reference in a
  workflow. Branches are mutable.
- **Never skip pre-commit hooks** with `--no-verify`.
- **Release signing keystores are never committed.** `android/key.properties`
  is gitignored; the Android release `buildType` is intentionally left
  without a fallback signing config so forgetting to wire up a real
  keystore fails the build instead of silently shipping with the debug
  key. CI release pipelines populate `key.properties` from secrets at
  build time.
- **iOS development teams are not pinned in `project.pbxproj`** once
  the project has more than one contributor. Forcing a specific Apple
  `DEVELOPMENT_TEAM` leaks it to every contributor and CI runner.
  Each developer supplies their own team locally; CI uses
  `--no-codesign` for debug builds.

  > **Current deviation** — the project ships with the single-owner
  > team ID pinned because the release pipeline's `flutter build ipa
  > --release` archive step consumes it directly and there is exactly
  > one contributor today. Migrate this to an external `.xcconfig`
  > read from a GitHub secret when the project gains a second iOS
  > contributor, or convert the release archive step to pass
  > `DEVELOPMENT_TEAM` via `xcodebuild` flags instead.

## Codegen and Drift Detection

- Generated files (`*.g.dart`, `*.freezed.dart`, everything under
  `lib/l10n/generated/`) are committed — see
  [naming-conventions.md](naming-conventions.md).
- CI re-runs `flutter gen-l10n` and `dart run build_runner build` on
  every PR, then runs `git diff --exit-code` against the tracked
  generated paths. Any drift fails the job immediately. This prevents
  a subtle supply-chain hazard where a PR could introduce hand-crafted
  changes to generated files that the codegen would never reproduce.

## Logs

- Never log file contents, user input, or full file paths
- Error logs may include the basename only

## Permissions

- Request the minimum set: file access at the time of use
- The Android `INTERNET` permission is declared because of the repo-sync
  feature, but the app must remain fully usable when the permission is
  effectively unavailable (sync simply fails with an actionable message)
- No location, camera, microphone, or contacts permissions
