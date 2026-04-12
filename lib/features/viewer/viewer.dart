/// Public API for the `viewer` feature.
///
/// Cross-feature imports must go through this barrel — never reach into
/// a feature's internals (see
/// `docs/standards/architecture-standards.md`).
library;

export 'data/repositories/document_repository_provider.dart';
export 'domain/entities/document.dart';
export 'domain/repositories/document_repository.dart';
