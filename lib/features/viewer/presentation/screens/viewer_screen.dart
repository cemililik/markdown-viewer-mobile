import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/core/widgets/error_view.dart';
import 'package:markdown_viewer/core/widgets/loading_view.dart';
import 'package:markdown_viewer/features/viewer/application/viewer_document.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/presentation/failure_message_mapper.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/markdown_view.dart';
import 'package:path/path.dart' as p;

/// Screen that loads and renders a single markdown document.
///
/// Consumes [viewerDocumentProvider] for the given [documentId] and
/// dispatches on its [AsyncValue] state:
///
/// - **loading** — shared [LoadingView] with a localized label
/// - **error**   — shared [ErrorView] with a retry button that
///   invalidates the provider to kick off a fresh load
/// - **data**    — [MarkdownView] renders the parsed document
///
/// The app bar title uses the file's basename (e.g. `README.md`) or a
/// localized fallback during loading. The presentation layer never
/// reaches into the data layer — it only talks to the application
/// provider, which is the contract enforced by
/// `docs/standards/architecture-standards.md`.
class ViewerScreen extends ConsumerWidget {
  const ViewerScreen({required this.documentId, super.key});

  final DocumentId documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(viewerDocumentProvider(documentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(documentId, l10n.viewerUnnamedDocument)),
      ),
      body: async.when(
        loading: () => LoadingView(label: l10n.viewerLoading),
        error: (error, stackTrace) {
          final failure =
              error is Failure
                  ? error
                  : UnknownFailure(
                    message: 'Unexpected error in viewer',
                    cause: error,
                  );
          return ErrorView(
            message: mapFailureToViewerMessage(failure, l10n),
            retryLabel: l10n.actionRetry,
            onRetry: () => ref.invalidate(viewerDocumentProvider(documentId)),
          );
        },
        data: (document) => MarkdownView(document: document),
      ),
    );
  }

  String _titleFor(DocumentId id, String fallback) {
    final basename = p.basename(id.value);
    return basename.isEmpty ? fallback : basename;
  }
}
