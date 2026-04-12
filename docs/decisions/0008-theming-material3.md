# ADR-0008: Material 3 with dynamic color

- **Status**: Accepted
- **Date**: 2026-04-12

## Context

Flutter ships first-class Material 3 support. For iOS we can still lean
on Material 3 for structure while using Cupertino idioms at specific
touch points (e.g., share sheet). Dynamic color on Android 12+ gives
users seamless system-matching themes.

## Decision

- Build the UI with **Material 3** (`useMaterial3: true`)
- Define a seed color scheme; derive light and dark schemes from it
- Use **`dynamic_color`** (≥ 1.7) to adopt the Android 12+ system color
  scheme when available
- Cupertino widgets are used only for platform-conventional surfaces
  (share sheet, file picker) via adaptive wrappers

## Consequences

### Positive

- Modern, consistent visual language
- System-matching on modern Android
- Single theme source of truth

### Negative

- Material 3 is still evolving; occasional Flutter upgrades change pixels
- iOS users see a Material-leaning visual style

## Alternatives Considered

### Fully adaptive (Material on Android, Cupertino on iOS)

Rejected: doubles widget-tree maintenance for marginal UX gains in a
reading-first app.

### Material 2

Rejected: deprecated direction.
