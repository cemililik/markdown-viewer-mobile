# Mermaid — class diagrams

Class diagrams capture the static structure of a system: types,
their fields and methods, and the relationships between them.

## Basic class

```mermaid
classDiagram
    class Document {
        +String source
        +List~HeadingRef~ headings
        +int blockCount
        +wordCount() int
    }
```

## Relationships

```mermaid
classDiagram
    class ViewerScreen {
        -DocumentId documentId
        -String? initialAnchor
        +build(context) Widget
    }

    class MarkdownView {
        -Document document
        -Map~int, GlobalKey~ blockKeys
        +build(context) Widget
    }

    class Document {
        +String source
        +List~HeadingRef~ headings
    }

    class HeadingRef {
        +int level
        +String text
        +String anchor
        +int blockIndex
    }

    ViewerScreen *-- MarkdownView : contains
    MarkdownView o-- Document : renders
    Document "1" --> "*" HeadingRef : has
```

## Inheritance and interfaces

```mermaid
classDiagram
    class NativeLibraryFoldersChannel {
        <<abstract>>
        +pickDirectory() Future~NativeFolderPick~
        +listDirectory(bookmark) Future~List~
        +readFileBytes(bookmark, path) Future~Uint8List~
    }

    class NativeLibraryFoldersChannelImpl {
        -MethodChannel channel
        +pickDirectory() Future~NativeFolderPick~
        +listDirectory(bookmark) Future~List~
        +readFileBytes(bookmark, path) Future~Uint8List~
    }

    class FakeChannel {
        -Uint8List payload
        +pickDirectory() Future~NativeFolderPick~
    }

    NativeLibraryFoldersChannel <|-- NativeLibraryFoldersChannelImpl
    NativeLibraryFoldersChannel <|.. FakeChannel : test-only
```

## Composition with cardinality

```mermaid
classDiagram
    class SyncedRepo {
        +int id
        +String provider
        +String owner
        +String repo
        +String ref
        +String localRoot
        +DateTime lastSyncedAt
        +int fileCount
    }

    class SyncedFile {
        +int id
        +int repoId
        +String remotePath
        +String localPath
        +String sha
        +int size
        +String status
    }

    class AppDatabase {
        +getAllRepos() List~SyncedRepo~
        +upsertFile(file) int
        +deleteFilesNotIn(repoId, retained) void
    }

    AppDatabase "1" o-- "*" SyncedRepo : stores
    SyncedRepo "1" *-- "*" SyncedFile : contains
```

## Enumerations

```mermaid
classDiagram
    class SyncStatus {
        <<enumeration>>
        ok
        partial
        failed
    }

    class ReadingTheme {
        <<enumeration>>
        light
        dark
        sepia
        system
    }

    class SettingsStore {
        <<interface>>
        +readTheme() ReadingTheme
        +writeTheme(theme) Future
    }

    SettingsStore ..> ReadingTheme : returns
```
