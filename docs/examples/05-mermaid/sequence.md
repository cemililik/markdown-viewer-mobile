# Mermaid — sequence diagrams

Sequence diagrams trace the lifecycle of a request across
participants over time.

## Simple request / response

```mermaid
sequenceDiagram
    participant User
    participant App
    participant GitHub

    User->>App: Tap "Sync"
    App->>GitHub: GET /repos/owner/repo/git/trees/main
    GitHub-->>App: JSON tree
    App->>GitHub: GET raw/owner/repo/main/file.md
    GitHub-->>App: file bytes
    App-->>User: Library updated
```

## With activation bars

```mermaid
sequenceDiagram
    participant User
    participant Viewer
    participant Parser
    participant Renderer

    User->>+Viewer: Open document
    Viewer->>+Parser: parse(source)
    Parser-->>-Viewer: Document
    Viewer->>+Renderer: buildWidgets(document)
    Renderer-->>-Viewer: List<Widget>
    Viewer-->>-User: Rendered document
```

## Alternative paths

```mermaid
sequenceDiagram
    participant User
    participant App
    participant Store

    User->>App: Tap link
    App->>App: Parse href
    alt Anchor link
        App->>Store: Find heading
        Store-->>App: HeadingRef
        App->>User: Scroll to heading
    else Cross-file link
        App->>Store: Does file exist?
        Store-->>App: Yes
        App->>User: Navigate to target
    else External link
        App->>User: Launch system browser
    else Unknown
        App->>App: Log + drop
    end
```

## Looping interaction

```mermaid
sequenceDiagram
    participant Sync
    participant Dio
    participant API

    Sync->>API: Fetch tree (recursive)
    API-->>Sync: File list
    loop For each file
        Sync->>Dio: GET raw content
        Dio-->>Sync: File bytes (< 5 MB)
        Sync->>Sync: Write to local mirror
    end
    Sync->>Sync: Delete orphans
    Sync-->>Sync: Sync complete
```

## Parallel activities

```mermaid
sequenceDiagram
    participant App
    participant Android
    participant iOS

    App->>Android: build appbundle
    App->>iOS: build ipa
    par Android track
        Android-->>App: AAB uploaded
    and iOS track
        iOS-->>App: IPA uploaded
    end
    App->>App: Create GitHub Release
```

## Notes

```mermaid
sequenceDiagram
    participant User
    participant App
    participant Keychain

    User->>App: Enter PAT
    Note right of App: Never logged,<br/>never in database
    App->>Keychain: Store token
    Keychain-->>App: ok
    Note over App,Keychain: Encrypted at rest<br/>(iOS Keychain / Android Keystore)
    App-->>User: Sync ready
```
