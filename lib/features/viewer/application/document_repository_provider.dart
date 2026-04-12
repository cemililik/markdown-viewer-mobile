import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/features/viewer/domain/repositories/document_repository.dart';

/// Application-layer binding point for the [DocumentRepository] port.
///
/// The provider is declared here rather than in the data layer so the
/// application layer (`viewer_document.dart` and the rest of the
/// feature's use cases) can depend on an abstract symbol without ever
/// importing `data/`. The concrete wiring happens at the composition
/// root — see `lib/main.dart`, which supplies a real
/// `DocumentRepositoryImpl` via `ProviderScope.overrides`.
///
/// The default build throws on purpose: a test or composition root
/// that forgets to register an override gets a loud, immediate error
/// instead of silently using the wrong implementation.
final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  throw UnimplementedError(
    'documentRepositoryProvider must be overridden in the composition '
    'root (lib/main.dart) or in tests with a concrete DocumentRepository. '
    'No default implementation is registered — the application layer is '
    'forbidden from importing data-layer symbols directly.',
  );
});
