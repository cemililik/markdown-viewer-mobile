# ADR-0011: Network access policy — user-initiated only

- **Status**: Accepted
- **Date**: 2026-04-12
- **Supersedes**: portions of ADR-0005 and the original "no network" rule

## Context

The original v1 scope ruled out all network access (see security and
vision documents). That rule supported the offline-first reading
experience and minimized the attack surface.

A new requirement has emerged: users want to **pull markdown
documentation from a public git repository URL** into their local
library, mirroring the directory structure. This requires HTTP requests
to a remote git provider, which conflicts with the original "no network"
constraint.

We need a clear policy that:

- Allows the new repo-sync feature to make network calls
- Preserves the offline-first reading experience
- Preserves the privacy guarantee (no telemetry, no background traffic)
- Keeps the attack surface as small as possible

## Decision

Network access is **allowed only when explicitly initiated by the user**
through one of these flows:

1. **Repo sync** — the user pastes a URL and taps "Sync"
2. **Repo refresh** — the user explicitly refreshes a previously synced repo
3. **Reading the file the user opened** — never; reading remains 100% local

Hard rules:

- **No background network activity.** No periodic refresh, no
  pre-fetching, no analytics, no crash reporting that calls home.
- **No automatic network calls on app start, navigation, or scroll.**
- **All HTTP requests originate from the `repo_sync` feature** and use
  the project's single shared HTTP client.
- **The mermaid WebView remains fully sandboxed** with `blockNetworkLoads: true`.
  WebView network rules are unchanged.
- **The user can fully use the app with the network permission denied.**
  Sync simply fails with an actionable error.
- **No telemetry or analytics ever.** This is unchanged.

## Consequences

### Positive

- The repo-sync feature is unblocked
- Offline-first reading is preserved as the default mode
- Privacy posture is preserved — no calls home, no third parties
- Threat model stays narrow: one feature, one client, one allow-list of hosts

### Negative

- Slightly larger attack surface than zero-network
- Requires an HTTP client dependency (see ADR-0012)
- Security standard must be updated to describe network rules

## Alternatives Considered

### Keep the strict "no network" rule and drop repo sync

Rejected: the user explicitly asked for the sync feature, and the value
of pulling a project's docs onto a phone is high for the target audience.

### Allow general network access for any feature

Rejected: too broad; opens the door to telemetry creep and background
traffic that erodes the privacy posture.

### Implement sync via the platform share-sheet only (no in-app HTTP)

Rejected: the share-sheet path requires the user to fetch each file in
another app first, which defeats the recursive directory sync use case.
