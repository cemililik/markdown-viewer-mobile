/// Public API for the `viewer` feature.
///
/// Cross-feature imports must go through this barrel — never reach into
/// a feature's internals (see
/// `docs/standards/architecture-standards.md`).
///
/// The barrel intentionally re-exports **only** the domain layer
/// (entities and repository ports). The data-layer implementation
/// (`DocumentRepositoryImpl`, the `documentRepositoryProvider`
/// Riverpod binding, the raw `MarkdownParser`) is internal to the
/// feature and must not leak through this barrel — consumers outside
/// the feature depend on the port, never on the concrete class or its
/// provider wiring. An application-layer provider that wraps the
/// repository will be added in a later phase and re-exported here.
library;

export 'domain/entities/document.dart';
export 'domain/repositories/document_repository.dart';
