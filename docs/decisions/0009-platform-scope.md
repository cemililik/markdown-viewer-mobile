# ADR-0009: Target iOS + Android only for v1

- **Status**: Accepted
- **Date**: 2026-04-12

## Context

Initial scoping included HarmonyOS native support via the OpenHarmony
Flutter engine fork (`gitee.com/openharmony-sig/flutter_flutter`).
Supporting HarmonyOS natively would require:

- A separate Flutter engine and toolchain
- A separate CI pipeline
- Platform-channel reimplementation for every plugin we use
- Ongoing tracking of the upstream fork's divergence from mainline Flutter

## Decision

**HarmonyOS native support is out of scope for v1.** The app targets
**iOS 14+** and **Android 8.0 (API 26)+** only. HarmonyOS devices that
support Android apps can install the Android build.

## Consequences

### Positive

- Reduced toolchain complexity — one stable Flutter channel
- Single CI pipeline
- Faster iteration, narrower test matrix
- Clearer roadmap and shorter time-to-MVP

### Negative

- No native HarmonyOS experience — affected users get the Android fallback
- Cannot list a native presence in the HarmonyOS app store for v1

## Alternatives Considered

### Target HarmonyOS native in v1

Rejected: complexity cost is high and the benefit lands after v1.

### Drop Android, target iOS only

Rejected: Android user base is our primary audience for technical docs.

## Revisit Criteria

Re-evaluate for v2 once:

- The OpenHarmony Flutter engine reaches a stable release cadence
- Plugin compatibility is well understood
- There is concrete user demand
