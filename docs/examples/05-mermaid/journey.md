# Mermaid — user journey

User journey diagrams map the emotional arc of an interaction step
by step. Each task on a row gets a score (1–5) and an optional
actor. Useful for UX reviews where you want to see at a glance
which steps are friction and which are delight.

## First-time sync

```mermaid
journey
    title First-time sync experience
    section Discovery
      Open app: 5: User
      See empty library: 3: User
      Notice "Try it" card: 4: User
    section Sync
      Tap "Try it": 5: User
      Watch progress: 4: User, App
      See success: 5: User, App
    section Reading
      Tap first document: 5: User
      Scroll through: 5: User
      Tap TOC heading: 5: User, App
      Bookmark: 4: User
```

## Private repo setup

```mermaid
journey
    title Bring-your-own private repo
    section Learn
      Read docs: 4: User
      Create PAT on GitHub: 3: User
    section Configure
      Open sync screen: 4: User
      Paste URL: 4: User
      Tap "Use token": 3: User
      Paste PAT: 3: User
    section Sync
      Start sync: 5: User, App
      Wait for download: 4: User, App
      Verify file count: 5: User
```

## Share a document out

```mermaid
journey
    title Export to PDF and share
    section Reading
      Scroll to a section: 5: User
      Decide to share: 4: User
    section Export
      Tap share menu: 5: User
      Pick "Export PDF": 4: User
      Wait for render: 3: User, App
    section Share
      See system sheet: 5: User
      Pick recipient: 5: User
      Delivery complete: 5: User
```

## Adding a local folder

```mermaid
journey
    title Add a folder from Files app
    section Pick
      Open drawer: 4: User
      Tap "Add source": 5: User
      Pick folder: 4: User
      System picker shows tree: 5: System
      Confirm selection: 5: User
    section Read
      Folder appears in drawer: 5: User, App
      Tap file: 5: User
      Viewer opens: 5: User, App
```
