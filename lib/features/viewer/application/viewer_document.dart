import 'package:markdown_viewer/features/viewer/application/document_repository_provider.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'viewer_document.g.dart';

/// Application-layer entry point for loading a markdown document.
///
/// This provider is what presentation code (ViewerScreen) depends on.
/// It watches the abstract [documentRepositoryProvider] declared in
/// the application layer — never the concrete data-layer class — and
/// delegates the actual I/O to whatever concrete repository has been
/// wired at the composition root.
///
/// Parametrized by [DocumentId] so every distinct path gets its own
/// provider instance — `ref.invalidate(viewerDocumentProvider(id))`
/// forces a reload for one document without touching any others.
@riverpod
Future<Document> viewerDocument(Ref ref, DocumentId id) async {
  final repository = ref.watch(documentRepositoryProvider);
  return repository.load(id);
}
