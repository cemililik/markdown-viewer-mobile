# Mermaid — timelines

Timelines chart events across calendar time. Each section rolls up
into a heading; each entry is a point on the line.

## Project delivery

```mermaid
timeline
    title MarkdownViewer — from scaffold to v1.0
    2026-02 : Project scaffold
            : CI pipeline + analysis_options
    2026-03 : MVP rendering
            : Mermaid + math + admonitions
            : Reading-comfort toolbar
    2026-04 : Repo sync
            : Code review (128 findings)
            : Security review (H/M closed)
            : Performance audit
            : v1.0.0 public release
```

## Changelog at a glance

```mermaid
timeline
    title Version history
    2026-04-14 : v0.2.0 (first beta)
    2026-04-15 : v0.2.1 (Sentry + onboarding)
               : v0.2.2 (Xcode iOS 26 pin)
    2026-04-17 : v1.0.0 (first public)
               : v1.0.1 (anchor + cross-file fix)
               : v1.0.2 (perf + release hardening)
```

## Day-in-the-life of a release

The timeline syntax uses `:` as the section-to-event separator, so
an entry label like `T+00:00` would be ambiguous. We reach for
plain-English minute labels instead.

```mermaid
timeline
    title Tag-triggered release pipeline (elapsed minutes)
    0 min  : Tag pushed
    1 min  : version job parses semver
    2 min  : verify runs (lint / analyze / test)
    5 min  : android-release starts (R8 + sign + upload)
           : ios-release starts in parallel
    15 min : Play Console internal track ready
    20 min : TestFlight upload processing
    21 min : GitHub Release published
    35 min : TestFlight build visible to testers
```
