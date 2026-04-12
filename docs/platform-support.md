# Platform Support

## Supported Platforms

| Platform | Minimum | Target | Status |
|----------|---------|--------|--------|
| iOS | 14.0 | 17.x | Supported |
| iPadOS | 14.0 | 17.x | Supported |
| Android Phone | API 26 (8.0) | API 34 (14) | Supported |
| Android Tablet | API 26 (8.0) | API 34 (14) | Supported |

## Explicitly Out of Scope (v1)

- **HarmonyOS native** — requires the OpenHarmony Flutter engine fork,
  which adds toolchain complexity, a separate CI pipeline, and uncertain
  upstream stability. Deferred to post-v1. See
  [ADR-0009](decisions/0009-platform-scope.md). HarmonyOS devices that
  support Android apps can install the Android build.
- **Desktop (macOS, Windows, Linux)** — different UX requirements
- **Web** — Flutter Web's performance on large markdown documents falls
  below our non-functional requirements
- **Wear OS / watchOS** — form factor mismatch

## Device Test Matrix

Minimum target devices that must pass the full test suite before release:

### iOS

- iPhone SE (2nd gen) — smallest supported screen
- iPhone 12 — mid-range baseline
- iPhone 15 Pro — high-end
- iPad (9th gen) — tablet baseline
- iPad Pro 12.9" — large tablet

### Android

- Pixel 4a — low-end baseline
- Pixel 6a — mid-range baseline
- Pixel 8 Pro — high-end
- Samsung Galaxy Tab A8 — tablet baseline

## Orientation & Form Factor

- Portrait: all devices
- Landscape: all devices
- Split-screen (Android) and Slide Over (iPad) must not crash; layout
  adapts gracefully above 320 dp width
- Foldables: phone mode and unfolded mode; no special UI for v1

## Platform-Specific Notes

### iOS

- Use Cupertino idioms where platform-conventional (e.g., share sheet)
- Respect Dynamic Type settings
- Handle iOS 14 scoped file access correctly
- Files app integration via `UIDocumentPickerViewController`, wrapped by
  `file_picker`

### Android

- Honor scoped storage on API 29+
- Register as a file handler for `text/markdown` and the `.md` extension
- Handle the share menu via share intent
- Support the predictive back gesture on API 34+
