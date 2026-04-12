# ADR-0001: Use Flutter as the application framework

- **Status**: Accepted
- **Date**: 2026-04-12

## Context

The product targets iOS and Android with one engineering team. Options:

- Native iOS (Swift) + native Android (Kotlin)
- React Native
- Flutter
- .NET MAUI

We need high render performance (60fps on long documents), a single
rendering pipeline that behaves identically across platforms, and strong
custom-widget support for advanced markdown blocks (mermaid, math, code).

## Decision

We will build the app with **Flutter** (stable channel, ≥ 3.41) using
the **Dart** version bundled with that Flutter release (≥ 3.7).

## Consequences

### Positive

- One codebase, one rendering pipeline across iOS and Android
- Skia / Impeller rendering gives us pixel-level control for custom blocks
- Strong widget composition for a rendering-heavy app
- Hot reload accelerates iteration on the rendering model

### Negative

- Platform-specific integrations (share intent, default handler) require
  channel code or plugins
- Binary size is larger than a native app
- HarmonyOS support is out of scope (see ADR-0009)

## Alternatives Considered

### Native iOS + Native Android

Rejected: doubles engineering cost, forces two rendering pipelines to be
kept in sync, slows iteration on the rendering model.

### React Native

Rejected: bridged rendering produces inconsistent scroll and layout
performance for long markdown documents; custom block widgets are
cumbersome; Skia integration is less mature than Flutter's.

### .NET MAUI

Rejected: weaker ecosystem for markdown / mermaid / math rendering and a
smaller pool of contributors.
