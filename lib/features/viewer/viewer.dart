/// Public API for the `viewer` feature.
///
/// Cross-feature imports must go through this barrel — never reach into
/// a feature's internals (see
/// `docs/standards/architecture-standards.md`).
///
/// The barrel intentionally re-exports only the **domain**,
/// **application**, and **presentation** layers. The data-layer
/// implementation (`DocumentRepositoryImpl`, the raw `MarkdownParser`,
/// the `documentRepositoryProvider` Riverpod binding) is internal to
/// the feature and must not leak through this barrel — consumers
/// outside the feature depend on the domain port and the
/// `viewerDocumentProvider` application provider, never on the
/// concrete data-layer symbols.
library;

export 'application/viewer_document.dart';
export 'domain/entities/document.dart';
export 'domain/repositories/document_repository.dart';
export 'presentation/screens/viewer_screen.dart';
