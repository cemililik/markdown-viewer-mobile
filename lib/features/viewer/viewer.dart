/// Public API for the `viewer` feature.
///
/// Cross-feature imports must go through this barrel — never reach into
/// a feature's internals (see
/// `docs/standards/architecture-standards.md`).
///
/// The barrel re-exports only the **domain**, **application**, and
/// **presentation** layers. Concrete data-layer symbols
/// (`DocumentRepositoryImpl`, `MarkdownParser`) stay internal to the
/// feature — the composition root (`lib/main.dart`) is the single
/// place allowed to import them directly to wire up the
/// [documentRepositoryProvider] override.
library;

export 'application/document_repository_provider.dart';
export 'application/viewer_document.dart';
export 'domain/entities/document.dart';
export 'domain/repositories/document_repository.dart';
export 'presentation/screens/viewer_screen.dart';
