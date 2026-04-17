# Mermaid — entity-relationship diagrams

ER diagrams model data structure: entities, their attributes, and
the relationships (one-to-one, one-to-many, many-to-many) between
them.

## Basic relationship

```mermaid
erDiagram
    SYNCED_REPOS ||--o{ SYNCED_FILES : contains
    SYNCED_REPOS {
        int id PK
        string provider
        string owner
        string repo
        string ref
        string local_root
        int last_synced
    }
    SYNCED_FILES {
        int id PK
        int repo_id FK
        string remote_path
        string local_path
        string sha
        int size
        string status
    }
```

## Multi-table schema

```mermaid
erDiagram
    USER ||--o{ PAT : "stores (0..1)"
    USER ||--o{ SYNCED_REPOS : owns
    SYNCED_REPOS ||--o{ SYNCED_FILES : contains
    SYNCED_REPOS }|--|| PROVIDER : "hosted on"

    USER {
        string device_id PK "not persisted, no account"
    }
    PAT {
        string scope PK "keychain entry"
        string token "encrypted at rest"
    }
    PROVIDER {
        string name PK
        string api_base_url
    }
    SYNCED_REPOS {
        int id PK
        string provider FK
        string owner
        string repo
        string ref
        string sub_path
        int last_synced
        int file_count
        string status
    }
    SYNCED_FILES {
        int id PK
        int repo_id FK
        string remote_path
        string local_path
        string sha
        int size
        string status
    }
```

## Cardinality reference

Mermaid uses a shorthand for the two ends of a relationship line:

| Notation | Meaning        |
|----------|----------------|
| `\|\|`   | exactly one    |
| `o\|`    | zero or one    |
| `\|{`    | one or more    |
| `o{`     | zero or more   |

So `SYNCED_REPOS ||--o{ SYNCED_FILES` reads as "each repo has zero
or more files, and each file belongs to exactly one repo."

## Preferences table

```mermaid
erDiagram
    SETTINGS ||--|| READING_PREFS : "one-to-one"
    SETTINGS ||--|| THEME_PREFS : "one-to-one"
    SETTINGS ||--|| OBSERVABILITY : "one-to-one"

    READING_PREFS {
        string font_scale
        string reading_width
        string line_height
        bool keep_screen_on
    }
    THEME_PREFS {
        string theme_mode
        bool use_dynamic_color
        bool sepia_enabled
    }
    OBSERVABILITY {
        bool crash_reports_enabled
    }
```
