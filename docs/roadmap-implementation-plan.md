# Prioritized Roadmap Implementation Plan

- **Status**: Approved for implementation
- **Date**: 2026-07-30
- **Owner**: Cemil Ilık
- **Source**: `docs/analysis/17-prioritized-roadmap.md`

## Objective

Implement every actionable item in the prioritized roadmap without silently
deferring confirmed work. Items that the roadmap itself marks as
measurement-gated are completed by producing the required evidence, recording
the decision, obtaining the required ADR approval, and implementing the
evidence-backed outcome.

The implementation runs on `development`. Before this plan was drafted,
`development` was merged with `main`, pushed, and verified to have the same tree
as `main`.

## Mandatory Step Protocol

Each implementation step follows the same protocol:

1. Re-read the applicable accepted ADRs and standards.
2. Add or repair tests so the intended behavior can fail before changing it.
3. Implement the bounded step.
4. Run formatting, generation, static analysis, targeted tests, and the
   proportionate full suite.
5. Commit the implementation.
6. Run an independent GPT-5.6 Sol review round with separate reviewers for:
   - correctness, security, and hostile-input behavior;
   - architecture, concurrency, storage, and lifecycle behavior; and
   - tests, accessibility, localization, UX, and performance.
7. Reproduce and validate every finding, fix verified findings, rerun the
   relevant gates, and commit the fixes.
8. Run the same independent review dimensions with GPT-5.6 Terra reviewers.
9. Reproduce and validate every finding, fix verified findings, rerun the
   relevant gates, and commit the fixes.
10. Record the step evidence and continue automatically unless an ADR approval,
    credential owner action, or external-state fact is genuinely blocking.

Review prompts include the accepted decisions, the exact commit range, roadmap
acceptance criteria, threat boundaries, and tests. A review finding is not
implemented merely because an agent reported it; it must be reproduced or
otherwise verified against the repository contract.

## Implementation Steps

### Step 0 — Decision baseline and external readiness

Accept and index ADR-0015 through ADR-0025, record signing continuity facts,
establish the security contact, configure the protected release environment,
and record all approved product defaults. This closes the decision portion of
`W0-03`, `W2-09`, and the governance prerequisites for later work.

### Step 1 — Test integrity, golden hygiene, and accessibility harness

Repair tests that cannot fail, isolate global test state, eliminate localized
string finders, fix the existing macOS golden regressions, establish the
contrast and semantics harnesses, and make failure diagnostics deterministic.

Roadmap: `W1-04`, `W1-09`, `W3-22`.

### Step 2 — Integration and performance gates

Run `integration_test` in CI, establish fixed-device benchmark budgets, capture
the current baseline, and make regressions fail before performance work starts.

Roadmap: `W1-02`, `W1-03`.

### Step 3 — Release, supply-chain, platform, and repository governance

Harden tag-derived values, signing and release metadata, lockfile enforcement,
workflow permissions, Dependabot, scheduled builds, secret cleanup, explicit
platform pins, minified/profile builds, licence checks, `SECURITY.md`, and
repository contribution furniture.

Roadmap: `W0-02`, `W0-03`, `W1-05`, `W2-13`, `W2-14`, `W4-12`.

### Step 4 — Privacy boundary and public disclosure

Centralize fail-closed diagnostic redaction, serialize consent, correct privacy
copy and data-erasure behavior, add the iOS privacy manifest, and remove or
truthfully disclose website processors. Remote observability remains disabled
throughout this step.

Roadmap: `W0-18`, `W0-19`, `W0-20`, `W0-21`.

### Step 5 — Observability activation and maintainer diagnostics

Inject the validated DSN only after Step 4 gates pass, upload symbols, complete
capture ownership and provider observation, and add a redacted diagnostics
surface with truthful build and consent state.

Roadmap: `W0-01`, `W1-27`, `W4-09`.

### Step 6 — Versioned native boundary

Implement the v1 platform-channel registry and typed adapters, move folder and
document I/O off platform main threads, add Kotlin and Swift parity tests, and
replace `file_picker` only after both native pickers pass the contract suite.

Roadmap: `W0-23`, `W1-26`, `W4-08`.

### Step 7 — Local storage, inbound intake, and bootstrap recovery

Move repository mirrors to backup-excluded Application Support, migrate
existing installs, disable unintended Files exposure, constrain and de-collide
file intake, preserve cold-start events, and render a recoverable bootstrap
failure instead of a blank application.

Roadmap: `W0-04`, `W0-05`, `W0-06`, `W0-17`, `W0-24`.

### Step 8 — Path and cross-store integrity

Introduce the injected containment service, validate every read/write/delete
path, implement generation-based atomic sync writes, enforce database natural
keys and foreign keys, and test every supported migration and crash boundary.

Roadmap: `W0-07`, `W0-08`, `W0-09`, `W0-10`, `W2-06`.

### Step 9 — Destructive actions and removal fan-out

Add confirmation, undo where recovery is possible, truthful partial-removal
states, and complete cleanup of caches, recents, positions, native grants,
mirrors, database rows, and separately confirmed credentials.

Roadmap: `W0-15`, `W0-16`.

### Step 10 — Failure semantics, cancellation, retries, and network truth

Implement the accepted failure taxonomy at every external boundary, propagate
real cancellation, preserve stack traces, recover secure-storage failures,
classify network and provider states precisely, expose swallowed failures, and
make retry actions invoke the owning operation.

Roadmap: `W1-10`, `W1-11`, `W1-12`, `W1-13`, `W1-14`, `W1-15`, `W1-28`,
`W2-07`.

### Step 11 — Repository sync verification, execution, and resumability

Build the complete sync test suite, implement Contents fallback, move CPU and
database work to the decided executors, use drift watch streams, show truthful
size/byte progress and metered warnings, and checkpoint only explicitly
user-started background work.

Roadmap: `W1-06`, `W2-15`, `W3-19`, `W4-03`.

### Step 12 — Mermaid availability, sandbox, and bounded caching

Implement timeouts, reset and process recovery, byte and decode budgets,
platform-independent navigation denial, one tested CSP policy, a persistent
bounded cache, hardened asset acquisition, unpredictable request correlation,
licence attribution, accessible failure UX, and the control tests that pin the
completed Wave 0 security boundaries.

Roadmap: `W0-11`, `W0-12`, `W0-22`, `W2-10`, `W3-04`, `W4-02`, `W4-10`.

### Step 13 — Search correctness and rendered-text mapping

Close the range crash, drive count/highlight/jump from one immutable list,
cancel stale generations, add accessible find-in-page behavior, and then move
to AST-derived rendered-text offsets without mutating syntax-bearing source.

Roadmap: `W0-13`, `W1-16`, `W3-05`, `W4-05`.

### Step 14 — Shared markdown model, math, footnotes, examples, and images

Create one markdown configuration and AST-derived model, implement the approved
currency-safe delimiter scanner, correct footnote behavior, turn the examples
corpus into a fixture, and add contained, capped local and mirrored image
resolution.

Roadmap: `W1-17`, `W1-18`, `W1-19`, `W4-13`.

### Step 15 — Document loading, reading position, and restoration

Enforce one streaming size and encoding policy on every entry path, use
transferable bytes where appropriate, replace pixel offsets with resolvable
anchors, and restore the open document and reading state after lifecycle and
process recreation.

Roadmap: `W1-20`, `W1-21`, `W3-21`.

### Step 16 — Library content search and refresh

Index native-backed folders, persist refreshed access handles, deduplicate
canonical documents, skip excluded trees, remove duplicate enumeration, retain
view state across refresh, expose partial-source failures, and meet the search
benchmark without per-character allocations.

Roadmap: `W1-22`, `W1-23`, `W3-15`.

### Step 17 — First-class PDF, export, and sharing

Stop deleting Unicode text, render the shared AST with bundled, licensed font
fallbacks, implement glyph preflight, page structure and outlines, propagate
progress and cancellation, sanitize one filename path, anchor iPad share
sheets, inspect share results, and clean temporary files.

Roadmap: `W0-14`, `W1-24`, `W1-25`, `W4-06`.

### Step 18 — Routing, onboarding, and library experience

Test redirects and error routes, implement the already accepted typed-route
decision, retain pending file opens, make upgrades show only relevant
onboarding, expose examples and default-handler settings, refresh relative
times, and add truthful About and licence surfaces.

Roadmap: `W1-07`, `W1-08`, `W3-18`, `W4-11`.

### Step 19 — Enforced architecture and maintainability

Machine-enforce layer imports and cycles, split the three identified god files,
standardize generated providers, correct provider lifecycles and derived state,
add domain ports and DI seams, and remove only verified dead code and approved
dependencies.

Roadmap: `W2-01`, `W2-02`, `W2-03`, `W2-04`, `W2-05`, `W2-08`.

### Step 20 — Accessibility, localization, and adaptive input

Complete document semantics, task-list/table/code/math accessibility,
contrast, 200% scaling, tap targets, reduced motion, bold/high-contrast modes,
announcements, keyboard focus and shortcuts, RTL layout, and English/Turkish
plural and placeholder completeness.

Roadmap: `W3-01`, `W3-02`, `W3-03`, `W3-06`, `W3-07`, `W3-08`, `W3-09`,
`W3-10`, `W3-11`, `W3-12`, `W3-13`.

### Step 21 — Viewer, startup, and website excellence

Memoize parsing and stable render configuration, isolate block repaints,
improve first frame and deferred initialization, complete reader interaction
polish, and make the static site useful without JavaScript with one localized
implementation and complete store/social metadata.

Roadmap: `W3-14`, `W3-16`, `W3-17`, `W3-20`.

### Step 22 — Responsive reading and typography

Implement the 600-pixel single/two-pane transition, Stage Manager and
split-screen behavior, focus continuity, breakpoint goldens, and persisted
reader typography and spacing controls.

Roadmap: `W4-04`, `W4-07`.

### Step 23 — Evidence-gated virtualization decision

Profile the materialized viewer after the preceding optimizations on the fixed
device matrix. Draft the required follow-up ADR with the measurements, pause
for maintainer approval as required by the ADR policy, and implement the
approved materialized or virtualized outcome with stable search, selection,
scrollbar, and anchor behavior.

Roadmap: `W4-01`.

### Step 24 — Coverage ratchet and documentation truth pass

Set evidence-backed coverage floors only after the new suites raise the
baseline, align every standard and product document with shipped behavior,
record approved ADR status transitions, remove stale analysis claims, verify
every roadmap identifier has evidence, and run the complete release matrix.

Roadmap: `W1-01`, `W2-09`, `W2-11`, `W2-12`.

## Completion Evidence

The roadmap is complete only when:

- every `W0-*` through `W4-*` item maps to a completed step and evidence;
- no accepted ADR is contradicted by code, standards, or product copy;
- all public APIs have Dartdoc and all new behavior has tests;
- formatting, generation, analysis, unit, widget, golden, integration, native,
  benchmark, profile, licence, and release workflow gates pass;
- the Android and iOS physical-device checks required by the standards are
  recorded;
- the working tree is clean and the commit history contains each implementation
  and review-fix checkpoint; and
- a pull request from `development` to `main` summarizes the evidence and is
  ready for the maintainer's detailed review.
