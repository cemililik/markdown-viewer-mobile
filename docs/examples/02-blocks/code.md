# Code blocks

The viewer uses `flutter_highlight` with the
`atom-one-light` / `atom-one-dark` themes depending on the current
Material-3 brightness. Over 190 languages are recognised — the
samples below cover the common ones.

## Plain fenced block (no language hint)

```
$ flutter build appbundle --release \
    --obfuscate \
    --split-debug-info=build/symbols
```

No language means no highlighting — still monospaced, still a code
block, but syntax is not tokenised.

## Dart

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final counterProvider = StateProvider<int>((ref) => 0);

class CounterScreen extends ConsumerWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Text('Count: $count');
  }
}
```

## Kotlin

```kotlin
package com.cemililik.markdown_viewer

import android.app.Activity
import android.content.Intent

class MainActivity : Activity() {
    companion object {
        private const val REQUEST_CODE_PICK_DIRECTORY = 0x4D4456
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == Intent.ACTION_VIEW) {
            handleInboundFile(intent.data)
        }
    }
}
```

## Swift

```swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions:
      [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## TypeScript

```typescript
interface HeadingRef {
  readonly level: 1 | 2 | 3 | 4 | 5 | 6;
  readonly text: string;
  readonly anchor: string;
}

function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s-]/gu, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '');
}
```

## Python

```python
from dataclasses import dataclass
from pathlib import Path

@dataclass(frozen=True)
class Document:
    source: str
    headings: list[HeadingRef]

    def word_count(self) -> int:
        return sum(1 for word in self.source.split() if word)
```

## Rust

```rust
use std::collections::HashMap;

#[derive(Debug, Clone)]
struct Document {
    source: String,
    headings: Vec<HeadingRef>,
}

impl Document {
    fn word_count(&self) -> usize {
        self.source.split_whitespace().count()
    }
}
```

## Go

```go
package main

import (
    "fmt"
    "strings"
)

func wordCount(source string) int {
    return len(strings.Fields(source))
}

func main() {
    fmt.Println(wordCount("hello markdown viewer"))
}
```

## Shell

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
echo "Building v${VERSION}..."
flutter build appbundle --release --obfuscate \
    --split-debug-info=build/symbols
```

## SQL

```sql
CREATE TABLE synced_repos (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    provider     TEXT    NOT NULL,
    owner        TEXT    NOT NULL,
    repo         TEXT    NOT NULL,
    ref          TEXT    NOT NULL,
    sub_path     TEXT    NOT NULL DEFAULT '',
    local_root   TEXT    NOT NULL,
    last_synced  INTEGER NOT NULL,
    UNIQUE(provider, owner, repo, ref, sub_path)
);
```

## JSON

```json
{
  "name": "markdown_viewer",
  "version": "1.0.1+1",
  "dependencies": {
    "flutter_riverpod": "^3.2.1",
    "markdown_widget": "^2.3.2+8",
    "flutter_math_fork": "^0.7.3"
  }
}
```

## YAML

```yaml
name: Release
on:
  push:
    tags:
      - 'v*'
jobs:
  version:
    name: Resolve version from tag
    runs-on: ubuntu-latest
    outputs:
      version_name: ${{ steps.parse.outputs.version_name }}
```

## Inline code

Inline code is for short tokens — method names like `setState`,
environment variables like `$HOME`, package specs like
`flutter_riverpod: ^3.2.1`. These use a subtle background tint
rather than full syntax highlighting.
