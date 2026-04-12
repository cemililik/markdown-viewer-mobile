# Error Handling Standards

## Principles

1. **Exceptions at boundaries, failures in domain**
2. **Never silently swallow errors** — log, rethrow, or convert to failure
3. **User-facing errors must be actionable**

## The `Failure` Hierarchy

Domain defines a sealed class:

```dart
sealed class Failure {
  const Failure({required this.message, this.cause});
  final String message;
  final Object? cause;
}

final class FileNotFoundFailure extends Failure { /* ... */ }
final class PermissionDeniedFailure extends Failure { /* ... */ }
final class ParseFailure extends Failure { /* ... */ }
final class RenderFailure extends Failure { /* ... */ }
final class UnknownFailure extends Failure { /* ... */ }
```

## Layer Responsibilities

### Data Layer

- May throw exceptions from underlying packages
- Wraps them in `Failure` types **at the repository boundary**
- Never lets a low-level exception leak upward

```dart
Future<Document> load(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    return _parser.parse(bytes);
  } on PathNotFoundException catch (e) {
    throw FileNotFoundFailure(message: 'File not found', cause: e);
  } on FormatException catch (e) {
    throw ParseFailure(message: 'Invalid markdown', cause: e);
  }
}
```

### Application Layer

- Catches `Failure` types in notifiers
- Converts to `AsyncValue.error` for the presentation layer to consume

### Presentation Layer

- Maps `Failure` → user message via `FailureMessageMapper`
- Renders error states via the shared `ErrorView` widget
- Never shows a raw exception message to the user

## Logging

- Every caught error is logged via the `logger` package
- Log entries must include failure type, message, and the original cause
- **Never** log file contents, user input, or PII

## User Messaging

- Messages are localized (see [localization-standards.md](localization-standards.md))
- Messages tell the user *what to do*, not just *what went wrong*
  - Bad: `FileNotFoundException: /path/to/file.md`
  - Good: `This file no longer exists. It may have been moved or deleted.`

## Graceful Degradation

- Single-block rendering failures (e.g., a broken mermaid diagram) must not
  crash the whole document — render an inline error placeholder and continue
- Document-level parser failures fall back to rendering raw source with a
  warning banner
