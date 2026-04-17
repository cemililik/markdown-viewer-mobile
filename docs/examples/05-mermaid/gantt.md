# Mermaid — Gantt charts

Gantt charts plot work over time: sequential tasks, parallel tracks,
milestones, and dependencies.

## Release timeline

```mermaid
gantt
    title MarkdownViewer v1.0 delivery
    dateFormat YYYY-MM-DD
    axisFormat %b %d

    section Foundation
    Project scaffold              :done, p0, 2026-02-01, 7d
    CI pipeline                   :done, p0b, after p0, 5d

    section MVP
    Parser + pipeline             :done, p1, 2026-02-15, 10d
    End-to-end thin slice         :done, p1b, after p1, 7d
    Mermaid + math + admonitions  :done, p1c, after p1b, 10d

    section Phase 4.5 — Repo sync
    GitHub URL parser             :done, p45a, 2026-03-20, 5d
    Tree API + download           :done, p45b, after p45a, 7d
    Drift persistence             :done, p45c, after p45b, 5d

    section Phase 5 — Release
    Code review                   :done, p5a, 2026-04-15, 2d
    Security review               :done, p5b, after p5a, 1d
    v1.0.0 tag                    :milestone, p5m, 2026-04-17, 0d
    v1.0.1 patch                  :done, p5c, after p5m, 1d
```

## Parallel tracks

```mermaid
gantt
    title Release pipeline — parallel platform jobs
    dateFormat HH:mm
    axisFormat %H:%M

    section Shared
    Checkout + deps       :done, s1, 00:00, 2m
    Verify (lint/test)    :done, s2, after s1, 4m

    section Android
    Keystore decode       :done, a1, after s2, 10s
    Build signed AAB      :done, a2, after a1, 5m
    Upload Play Console   :done, a3, after a2, 40s

    section iOS
    Xcode setup           :done, i1, after s2, 30s
    Cert + profile        :done, i2, after i1, 20s
    Build signed IPA      :done, i3, after i2, 9m
    Upload TestFlight     :done, i4, after i3, 1m

    section Release
    GitHub Release        :done, r1, after a3, 30s
```

## With milestones and critical tasks

```mermaid
gantt
    title Onboarding delivery with dependencies
    dateFormat YYYY-MM-DD

    section Design
    Wireframes            :done, d1, 2026-03-01, 5d
    Usability review      :done, d2, after d1, 3d

    section Engineering
    Screens + routing     :done, e1, after d2, 7d
    Animations            :done, e2, after e1, 4d
    A11y (reduce motion)  :crit, done, e3, after e2, 3d
    Localization (EN + TR):done, e4, after e1, 5d

    section QA
    Manual test pass      :done, q1, after e3, 2d
    Beta rollout          :milestone, q2, after q1, 0d
```
