# ADR-0024: Platform support and responsive layout

- **Status**: Accepted
- **Date**: 2026-07-30
- **Deciders**: Cemil Ilık
- **Owner**: Cemil Ilık
- **Revisit date**: 2027-01-30
- **Extends**: [ADR-0009](0009-platform-scope.md)

This ADR proposes explicit build targets and a responsive,
restoration-capable experience for supported phones, tablets, and iPad
multi-window modes.

## Context

ADR-0009 establishes iOS 14+ and Android API 26+ as the supported runtime
floor, but Android build values are delegated to Flutter defaults and
platform documents disagree about target SDKs. A Flutter upgrade can
therefore change the shipped compatibility contract without a reviewed
project diff.

The `26` platform family is current, not a forecast. Apple has required App
Store Connect uploads to use Xcode 26 or later with an iOS 26 SDK since
2026-04-28. GitHub's `macos-26` hosted-runner inventory lists Xcode 26.4.1 and
the iOS 26.4 SDK on the decision date. The exact pins below intentionally
replace the current `macos-latest` and `latest-stable` aliases, whose resolved
tools can change without a repository diff.

The application supports iPad and Android tablets but currently presents a
phone layout at large widths. iPad Stage Manager and split-screen can
change the available width while the application is running. Opting out
would avoid layout work but would contradict the supported tablet
experience.

Process death and window recreation can also discard the open document and
reading position. Responsive layout and restoration must share one route
and state model rather than creating phone- and tablet-specific
application flows.

The optional keep-screen-awake setting also crosses application lifecycle and
native power-management boundaries. Its ownership and release behavior must be
explicit so a reader preference cannot become a background wake lock.

## Decision

### Supported platforms and explicit pins

The supported platform matrix is:

| Platform | Runtime minimum | Build target |
|----------|-----------------|--------------|
| iOS and iPadOS | 14.0 | Xcode 26.4.1 with the iOS 26.4 SDK |
| Android | API 26 (Android 8.0) | target API 36, compile API 36 |

Android build configuration pins these literal values:

- `minSdk = 26`;
- `targetSdk = 36`;
- `compileSdk = 36`; and
- `ndkVersion = "28.2.13676358"`.

iOS configuration pins deployment target `14.0` consistently in the
Podfile, Xcode project configurations, and generated build validation.
CI pins the `macos-26` runner and selects Xcode 26.4.1 explicitly rather than
inheriting either the runner label or Xcode default.

The ADR is the source of truth for the platform matrix. A test compares Gradle,
Podfile, Xcode, CI runner, and documentation values with this record. Raising a
runtime minimum requires a superseding ADR. Target, compile, NDK, runner-image,
or Xcode changes require a reviewed platform-maintenance change and the matrix
test must change in the same commit.

The external requirements used for the initial pins are:

- [Apple upcoming submission requirements][apple-requirements]; and
- [GitHub Actions `macos-26` installed-software inventory][github-runner].

[apple-requirements]: https://developer.apple.com/news/upcoming-requirements/
[github-runner]: https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md

HarmonyOS native, desktop, web, watchOS, and Wear OS remain outside the
supported application scope established by ADR-0009.

### Responsive navigation

- Width, not device model or orientation, chooses the layout.
- Below **600 logical pixels**, the app uses single-pane navigation.
- At **600 logical pixels and above**, the app uses a two-pane
  master-detail layout: library or source navigation in the leading pane
  and the active document in the detail pane.
- Directional placement follows the current text direction. The leading
  pane is not hardcoded to physical left.
- The layout responds continuously when split-screen, rotation, folding,
  or Stage Manager changes the window width. Crossing the breakpoint does
  not replace the route, re-read the document, or lose selection and
  reading position.
- Direct file-open and share-intent routes may show the detail pane without
  an initial library selection. Returning to the library remains
  available without constructing a second router.
- Presentation changes do not duplicate application state or data access.
  Both layouts consume the same Riverpod state and `go_router` route.

### Stage Manager and multi-window

- iPad Stage Manager and multitasking are supported; the application does
  not opt out through `Info.plist` capability restrictions.
- Every supported iPad window size must remain usable down to the
  platform-provided minimum. Widths below the breakpoint use the
  single-pane layout rather than a compressed two-pane variant.
- The app handles window-size changes without restart and without relying
  on full-screen safe-area assumptions.
- Android split-screen, freeform windows where available, landscape, and
  unfolded foldable widths follow the same breakpoint rules.
- This decision does not add multiple independent application windows.
  If iPad multi-scene document windows are proposed later, they require a
  separate ADR for ownership and synchronization.

### State restoration

- The root application and router use a stable restoration scope.
- Restored reader state contains a stable document identity, source
  identity, block or heading anchor, intra-block fraction, and the
  minimum presentation state needed to reopen the same reading context.
- Raw pixel offsets are not restoration data.
- Transient overlays, export progress, credentials, and document content
  are not serialized into restoration state.
- Restoration revalidates document access. If the source is unavailable,
  the app opens the library and presents a localized recovery message
  instead of looping or showing an empty viewer.
- A restored anchor is resolved again after asynchronous diagram layout.

### Keep-screen-awake lifecycle

- The setting is opt-in and defaults to off.
- The application requests the screen-awake capability only while a document
  reader is visible, the app is active, and the setting is enabled.
- The request is released when the reader route is no longer visible, the app
  becomes inactive or paused, the setting is disabled, or the owning provider
  is disposed.
- No sync, export, cache, or background continuation keeps the screen awake.
- Platform failure becomes a typed, localized state and never leaves the UI
  claiming that the preference is active when the native capability failed.
- Route, lifecycle, and setting transitions are idempotent so overlapping
  callbacks cannot leak or prematurely release another reader's ownership.

### Accessibility and input

- Both layouts preserve logical focus order, keyboard access, semantic
  heading structure, Dynamic Type or Android text scaling up to 200%, and
  minimum platform tap targets.
- Moving between one and two panes restores focus to the corresponding
  logical control or document block.
- Keyboard shortcuts operate on the active pane and never target an
  offstage duplicate.

### Verification

Automated coverage includes:

- configuration tests for every SDK and deployment pin;
- goldens at 320, 599, 600, 834, and 1024 logical pixels;
- both supported locales, light and dark themes, RTL, and 200% text scale
  at the breakpoint widths;
- widget tests proving that breakpoint changes preserve the route,
  document instance, selection, and anchor;
- Android split-screen and iPad Stage Manager integration scenarios;
- process-death restoration for an open local file and a mirrored file;
- keep-screen-awake acquisition and release across route, lifecycle, failure,
  and setting transitions; and
- inaccessible-source restoration with a localized recovery path.

Release validation continues to cover the smallest supported phone and a
representative Android tablet and iPad. Stage Manager behavior is a
release gate, not a best-effort manual check.

## Consequences

### Positive

- Flutter upgrades cannot silently raise the supported Android floor.
- Documentation, CI, and native projects share one platform matrix.
- Tablet and large-window users receive a reading-oriented master-detail
  experience.
- Stage Manager and split-screen are first-class rather than tolerated.
- Phone and tablet layouts share one route and state model.
- Process death no longer discards the reader's stable context.
- The keep-screen-awake preference cannot hold a background power assertion.

### Negative

- Supporting iOS 14 and API 26 increases compatibility testing and can
  constrain dependency upgrades.
- A two-pane layout requires more golden, semantics, keyboard, and
  restoration coverage.
- Stage Manager adds a release-test obligation on iPad hardware or a
  representative simulator environment.
- Wake-lock lifecycle needs route and application-lifecycle tests on both
  platforms.
- Pinning SDK and NDK values requires deliberate maintenance when stores
  or Flutter change their requirements.
- Restoring security-scoped file access can still require user recovery
  after the operating system revokes access.

## Alternatives considered

### Continue inheriting Flutter SDK defaults

Rejected because it allows a toolchain upgrade to change compatibility and
store targeting without an explicit project decision.

### Keep a phone layout on tablets

Rejected because it wastes available reading space and fails the
application's stated iPad and Android tablet support.

### Opt out of iPad Stage Manager and multitasking

Rejected because the app is a reading tool whose users benefit directly
from viewing documentation beside an editor, browser, or terminal.

### Use device-type checks

Rejected because an iPad can present a phone-sized window and a foldable
Android device can present a tablet-sized window. Available width is the
relevant constraint.

### Maintain separate phone and tablet routers

Rejected because duplicate navigation graphs drift and make restoration,
deep links, and file-open intents ambiguous.

### Restore raw scroll offsets

Rejected because offsets become invalid after width, font, theme, content,
or diagram-layout changes.

## Revisit criteria

Cemil Ilık will review this decision on **2027-01-30** against store SDK
requirements, Flutter stable support, device analytics from consenting
users, Stage Manager test results, and dependency minimum versions.
Earlier review is required before raising iOS 14 or API 26, changing the
600-pixel breakpoint, opting out of multitasking, or adding independent
multi-window scenes.
