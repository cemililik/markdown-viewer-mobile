import 'package:markdown_viewer/features/viewer/data/repositories/document_repository_provider.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'viewer_document.g.dart';

/// Application-layer entry point for loading a markdown document.
///
/// This is the provider that presentation code depends on — it never
/// imports the data-layer [documentRepositoryProvider] directly.
/// Routing the read through a dedicated application provider keeps the
/// feature barrel honest (see `docs/standards/architecture-standards.md`)
/// and gives us a single place to add caching, telemetry, or
/// transformations in the future.
///
/// Parametrized by [DocumentId] so every distinct path gets its own
/// provider instance — `ref.invalidate(viewerDocumentProvider(id))`
/// forces a reload for one document without touching any others.
@riverpod
Future<Document> viewerDocument(Ref ref, DocumentId id) async {
  final repository = ref.watch(documentRepositoryProvider);
  return repository.load(id);
}
