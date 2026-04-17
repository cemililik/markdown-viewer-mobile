# Mermaid — git graphs

Git graphs visualise branch topology: commits, branches, merges,
cherry-picks. Helpful for explaining a non-trivial branching
strategy or a past merge decision.

## Simple feature branch

```mermaid
gitGraph
    commit id: "init"
    commit id: "add parser"
    branch feature/anchors
    commit id: "resolveAnchor"
    commit id: "normalise case"
    checkout main
    commit id: "docs update"
    merge feature/anchors id: "merge anchors"
    commit id: "release prep"
```

## Concurrent feature branches

```mermaid
gitGraph
    commit id: "v0.2.2"
    branch feature/anchors
    branch feature/security
    checkout feature/anchors
    commit id: "resolveAnchor"
    commit id: "tests"
    checkout feature/security
    commit id: "host allow-list"
    commit id: "size caps"
    commit id: "tests"
    checkout main
    merge feature/security id: "merge security"
    merge feature/anchors id: "merge anchors"
    commit id: "v1.0.0"
```

## Release train

```mermaid
gitGraph
    commit id: "v1.0.0"
    branch hotfix/anchor
    checkout hotfix/anchor
    commit id: "anchor encoding"
    commit id: "cross-file links"
    checkout main
    merge hotfix/anchor id: "v1.0.1"
    branch perf/hardening
    checkout perf/hardening
    commit id: "R8 + obfuscate"
    commit id: "reading-time cache"
    commit id: "TOC direct scroll"
    checkout main
    merge perf/hardening id: "v1.0.2"
```

## Cherry-picks

```mermaid
gitGraph
    commit id: "a"
    commit id: "b"
    branch release/1.0
    commit id: "c"
    checkout main
    commit id: "d"
    commit id: "e: security fix"
    checkout release/1.0
    cherry-pick id: "e: security fix"
    commit id: "f: release notes"
    checkout main
    commit id: "g"
```
