# ADR-0015: Mermaid PNG rendering and sandbox policy v2

This ADR defines the recoverable, bounded, and platform-independent Mermaid
rendering sandbox.

- **Status**: Accepted
- **Date**: 2026-07-30
- **Deciders**: Cemil Ilık
- **Owner**: Cemil Ilık
- **Revisit date**: 2026-10-30
- **Supersedes**:
  [ADR-0005](0005-mermaid-rendering.md) in full, and only the Mermaid
  sandbox mechanism described by
  [ADR-0011](0011-network-access-policy.md). ADR-0011's broader network
  policy remains in force.

## Context

Mermaid is a JavaScript library and there is no pure-Dart implementation with
the required feature coverage. The application therefore renders untrusted
diagram source in a headless WebView and captures the result as a PNG.

ADR-0005 originally recorded an SVG pipeline. It was later edited in place to
describe the shipped PNG screenshot pipeline, contrary to the repository's ADR
immutability rule. The replacement text also attributes containment to a
combination of controls whose rationale is incomplete. In particular,
`securityLevel: 'antiscript'` is a compatibility setting and defense in depth;
it does not grant permission to treat local or synced diagram source as
trusted.

The current pipeline has additional availability and memory risks:

- initialization and render bridge calls have no wall-clock deadline;
- one unanswered callback can stop the serial queue for the process lifetime;
- a transient initialization failure is latched permanently;
- WebView process termination has no recovery path;
- disposing during initialization can leave a live native WebView;
- the shared page needs deterministic cleanup between render requests;
- navigation is not denied by a platform-independent policy;
- the PNG cache has an entry limit but no byte limit;
- bridge payloads and diagram source have no application-level byte limit; and
- inline PNGs are decoded at native screenshot resolution.

The app must retain Mermaid feature coverage and offline rendering while making
the sandbox fail closed, recoverable, and bounded.

## Decision

### Rendering contract

The renderer continues to use the bundled, integrity-checked Mermaid asset in
one headless `InAppWebView`. It returns PNG bytes plus natural width and height.
Raw SVG never crosses into Flutter presentation code.

Render requests are serialized. Identical in-flight requests collapse to one
operation, and completed results use a content-addressed cache key containing:

- Mermaid asset version;
- normalized diagram source;
- effective theme variables and theme CSS;
- text direction; and
- requested render width.

The application displays PNGs with a `cacheWidth` derived from the layout width
and device pixel ratio. PDF export uses the same content-addressed key or a
separate bounded scratch cache and releases each bitmap after embedding it.

### Trust and content policy

All Mermaid source is untrusted, regardless of whether it came from a local
file, a share intent, or repository sync.

The effective Mermaid security level is fixed to `antiscript` because supported
diagram types require HTML labels. User directives cannot weaken it. The
implementation must prove this behavior with the shipped Mermaid bundle rather
than relying on an undocumented trailing-directive merge rule.

`antiscript` is not the containment boundary. Containment is provided by:

- a null-origin page with no native APIs beyond the result callback;
- a deny-by-default Content Security Policy;
- denial of all navigation and external resource requests on both iOS and
  Android;
- no cookies, local storage, IndexedDB, file access, or universal file access;
- validation and sanitization of the generated SVG before DOM insertion; and
- strict bridge message and size validation.

Generated SVG insertion removes executable attributes and active URL schemes
before content reaches the sink. A validation failure produces a typed render
failure and no screenshot.

### Single source of truth for sandbox policy

The complete CSP and WebView settings live in one code-level sandbox-policy
constant. Documentation describes the required semantics and links to that
constant; it does not maintain a second literal policy.

Tests must assert the exact effective HTML and WebView configuration, including:

- `default-src`, `img-src`, `font-src`, `connect-src`, `base-uri`, and
  `form-action` deny by default;
- only the inline script and style capabilities required by the bundled
  renderer;
- disabled file, universal-file, storage, and cookie access;
- a single result bridge with a validated request identifier; and
- denial of top-level navigation, popups, redirects, and subresource requests.

`blockNetworkLoads` remains enabled wherever the platform supports it, but is
defense in depth. The cross-platform navigation and resource delegates are the
enforced network boundary.

### Deadlines and recovery

Every initialization and render bridge round trip has a constructor-injected
wall-clock deadline. Production defaults are:

- 15 seconds for sandbox initialization; and
- 30 seconds for one diagram render and screenshot.

A timeout completes the affected request with a typed timeout result, removes
it from all pending maps, and lets the queue continue.

The renderer exposes an idempotent `reset()` operation. A reset disposes the
controller, clears active callbacks and pending native state, rebuilds the page,
and rebinds the result callback before accepting a new render. Reset is
triggered after:

- a bridge timeout;
- WebView content-process termination;
- a malformed bridge response that makes request correlation unsafe; or
- another channel-level failure that leaves page state unknown.

A deterministic Mermaid parse error fails only that diagram and does not reset
the WebView.

Before each render, the sandbox removes the previous SVG, theme node contents,
temporary DOM nodes, and request-local state. A user-visible retry invokes
`reset()` before re-enqueuing a renderer-level failure.

Initialization has a budget of three consecutive automatic attempts. Exhausting
the budget fails queued requests without latching the renderer forever. An
explicit retry clears the budget and starts from a fresh sandbox.

`dispose()` wins every race. It cancels initialization, resolves all pending
requests with a disposal result, and prevents a late callback from restoring a
controller.

### Resource budgets

The initial limits are conservative engineering budgets, not measured device
claims:

- diagram source: 64 KiB of UTF-8;
- one encoded PNG bridge payload: 8 MiB;
- in-memory encoded-PNG LRU: 24 MiB and 64 entries, whichever is reached first;
  and
- one screenshot rectangle: the configured native backbuffer bounds.

Oversized source, payload, or screenshot dimensions produce a typed
too-large result. A tall diagram is reported as too large unless a tested
pagination path can capture it completely; silent clipping is forbidden.

Memory-pressure notification clears the renderer LRU, Flutter image-cache
entries owned by the diagram widgets, and any PDF scratch cache.

The owner will validate these provisional values on physical iOS and Android
devices before the revisit date against the project's RSS budget. A budget
change requires benchmark evidence and corresponding tests, but not a new ADR
unless the trust boundary changes.

### Verification requirements

The renderer is not complete until automated tests cover:

- initialization and render timeouts without queue starvation;
- recovery after process termination;
- disposal during unresolved initialization;
- malformed and mismatched bridge messages;
- attempted navigation and resource loading on both platform adapters;
- user attempts to select a weaker Mermaid security level;
- executable SVG attributes and active URL schemes;
- source, payload, screenshot, entry-count, and byte-budget limits;
- `cacheWidth` on inline images; and
- memory-pressure eviction.

At least one integration test renders representative diagrams with the bundled
Mermaid asset. Native adapter tests cover navigation denial and process
termination independently on Kotlin and Swift.

## Consequences

### Positive

- The PNG contract matches the pipeline the application intends to ship.
- One bad diagram or native callback cannot disable every later diagram.
- Network denial does not depend on one platform-specific WebView option.
- Untrusted input has explicit time, source, payload, and memory limits.
- The CSP and WebView policy cannot drift between code, tests, standards, and
  ADR prose.
- Failures degrade to an inline result while the rest of the document remains
  readable.

### Negative

- Reset and process-termination recovery add native lifecycle complexity.
- A 24 MiB encoded cache can still correspond to larger decoded bitmap
  residency, so widget-level decode sizing remains mandatory.
- Conservative limits can reject unusually large valid diagrams.
- Platform adapter and integration tests take longer than pure Dart tests.

### Neutral

- Persistent disk caching, visible-item prioritization, and document
  virtualization remain separate decisions.
- The sandbox remains offline and does not expand ADR-0011's network
  allow-list.

## Alternatives considered

### Keep ADR-0005 and edit it again

Rejected. Editing an accepted ADR again would further weaken the immutable
decision history and would not record the availability and resource policy.

### Use Mermaid `strict` mode as the primary control

Rejected. It breaks supported HTML-label diagram types and does not replace
network denial, navigation denial, CSP, or bridge validation.

### Return SVG to Flutter

Rejected. The previous path had cross-platform style and layout differences.
It would also move active-content sanitization into a second rendering
environment.

### Create a new WebView for every diagram

Rejected. It gives strong isolation but imposes unacceptable startup and memory
cost for diagram-heavy documents. Deterministic per-render cleanup plus
recoverable reset provides the required boundary with one sandbox.

### Render on a server

Rejected. It violates offline reading, sends document content off-device, and
expands the network and privacy surface.
