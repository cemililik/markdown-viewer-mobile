# Mermaid — state diagrams

State diagrams model behaviour — what states a system can be in and
which transitions are legal between them.

## Basic state machine

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Loading : open file
    Loading --> Rendered : parse success
    Loading --> Error : parse failure
    Rendered --> Idle : close
    Error --> Idle : dismiss
```

## Nested (composite) states

```mermaid
stateDiagram-v2
    [*] --> Syncing
    state Syncing {
        [*] --> FetchingTree
        FetchingTree --> Downloading : tree received
        Downloading --> WritingMirror : bytes received
        WritingMirror --> [*] : file saved
    }
    Syncing --> Completed : all files done
    Syncing --> Partial : some failed
    Syncing --> Failed : fatal error
    Completed --> [*]
    Partial --> [*]
    Failed --> [*]
```

## Parallel regions

```mermaid
stateDiagram-v2
    [*] --> ViewerOpen
    state ViewerOpen {
        state "Reading UX" as RUX {
            [*] --> Reading
            Reading --> Searching : tap search
            Searching --> Reading : close search
        }
        --
        state "Bookmark state" as BS {
            [*] --> Unmarked
            Unmarked --> Marked : tap bookmark
            Marked --> Unmarked : long-press clear
        }
    }
    ViewerOpen --> [*] : navigate back
```

## Decision with guards

```mermaid
stateDiagram-v2
    [*] --> OnTap
    OnTap --> ResolveAnchor : href starts with #
    OnTap --> ResolveRelative : href has no scheme
    OnTap --> LaunchExternal : http/https/mailto
    OnTap --> Block : other scheme

    ResolveAnchor --> Scroll : match found
    ResolveAnchor --> NoOp : no match

    ResolveRelative --> PushRoute : file exists
    ResolveRelative --> NoOp : file missing
```

## Notes on states

```mermaid
stateDiagram-v2
    [*] --> ConsentOff
    ConsentOff --> ConsentOn : user toggle
    ConsentOn --> ConsentOff : user toggle

    note right of ConsentOff
        Sentry not initialised.
        Zero network traffic.
    end note

    note right of ConsentOn
        Sentry.init runs.
        Crash reports sent on error.
    end note
```
