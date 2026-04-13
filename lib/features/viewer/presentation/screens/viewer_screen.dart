import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/core/widgets/error_view.dart';
import 'package:markdown_viewer/core/widgets/loading_view.dart';
import 'package:markdown_viewer/features/viewer/application/reading_position_store_provider.dart';
import 'package:markdown_viewer/features/viewer/application/viewer_document.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/document.dart';
import 'package:markdown_viewer/features/viewer/domain/entities/reading_position.dart';
import 'package:markdown_viewer/features/viewer/presentation/failure_message_mapper.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/markdown_view.dart';
import 'package:markdown_viewer/l10n/generated/app_localizations.dart';
import 'package:path/path.dart' as p;

/// Screen that loads and renders a single markdown document.
///
/// Owns the document scroll controller so the back-to-top FAB and
/// the reading-position bookmark feature can read offsets and
/// drive smooth scroll animations. Consumes
/// [viewerDocumentProvider] for the given [documentId] and
/// dispatches on its [AsyncValue] state:
///
/// - **loading** — shared [LoadingView] with a localized label
/// - **error**   — shared [ErrorView] with a retry button that
///   invalidates the provider to kick off a fresh load
/// - **data**    — [MarkdownView] renders the parsed document
///
/// On the first build of the data state the screen checks the
/// [ReadingPositionStore] for a saved position. If one exists the
/// scroll controller animates to that offset inside a post-frame
/// callback and a snackbar lets the user jump back to the top in
/// case the auto-restore was unwanted.
class ViewerScreen extends ConsumerStatefulWidget {
  const ViewerScreen({required this.documentId, super.key});

  final DocumentId documentId;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  static const double _backToTopThreshold = 200;

  final ScrollController _scrollController = ScrollController();
  late final ValueNotifier<bool> _isBookmarked;
  bool _showBackToTop = false;
  bool _restoreAttempted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Seed the bookmark indicator from persisted state so the AppBar
    // icon reflects the truth on the very first build. `ref` is a
    // `late final` on `ConsumerState` backed by the element's
    // `context as WidgetRef`, so reading a provider here is the
    // idiomatic path in Riverpod 3 — no need to reach into
    // `ProviderScope.containerOf` manually.
    final saved = ref
        .read(readingPositionStoreProvider)
        .read(widget.documentId);
    _isBookmarked = ValueNotifier<bool>(saved != null);
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > _backToTopThreshold;
    if (shouldShow != _showBackToTop) {
      setState(() => _showBackToTop = shouldShow);
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _isBookmarked.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _maybeRestoreReadingPosition() {
    if (_restoreAttempted) {
      return;
    }
    _restoreAttempted = true;
    final saved = ref
        .read(readingPositionStoreProvider)
        .read(widget.documentId);
    if (saved == null || saved.offset <= 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final maxOffset = _scrollController.position.maxScrollExtent;
      final target = saved.offset.clamp(0.0, maxOffset);
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
      _showLocalizedSnackBar((l10n) => l10n.viewerResumedFromBookmark);
    });
  }

  Future<void> _toggleBookmark() async {
    final store = ref.read(readingPositionStoreProvider);
    if (_isBookmarked.value) {
      _isBookmarked.value = false;
      await store.clear(widget.documentId);
      if (!mounted) {
        return;
      }
      _showLocalizedSnackBar((l10n) => l10n.viewerBookmarkCleared);
      return;
    }
    final offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    _isBookmarked.value = true;
    await store.write(
      ReadingPosition(
        documentId: widget.documentId,
        offset: offset,
        savedAt: DateTime.now(),
      ),
    );
    if (!mounted) {
      return;
    }
    _showLocalizedSnackBar((l10n) => l10n.viewerBookmarkSaved);
  }

  /// Shows a snackbar whose content reads its localized string on
  /// every rebuild, so an instant-apply locale change in settings
  /// flips the visible text while the snackbar is still on screen.
  ///
  /// Without the [Builder] wrap, `SnackBar(content: Text(l10n.xxx))`
  /// captures the localized string at the moment of construction
  /// and the shown snackbar keeps the stale copy even after
  /// `MaterialApp.locale` changes.
  ///
  /// The explicit 3 s duration matches the Material 3 guidance for
  /// short confirmation messages and keeps the snackbar from
  /// lingering over the back-to-top FAB.
  void _showLocalizedSnackBar(String Function(AppLocalizations l10n) resolve) {
    final messenger = ScaffoldMessenger.of(context);
    // Dismiss any already-visible snackbar so rapid tap sequences
    // (e.g. bookmark → unbookmark → bookmark) show immediate
    // feedback for the latest action instead of queueing behind
    // stale confirmations.
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Builder(builder: (context) => Text(resolve(context.l10n))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(viewerDocumentProvider(widget.documentId));

    return Scaffold(
      appBar: AppBar(
        // Explicit leading button: on a push-navigated viewer the
        // default `leading` from [AppBar] would already show one,
        // but deep links (`/viewer?path=…`) land directly on this
        // route with an empty stack. `canPop()` falls through to a
        // `go` back to the library so the user is never stranded.
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(LibraryRoute.location());
            }
          },
        ),
        title: Text(_titleFor(widget.documentId, l10n.viewerUnnamedDocument)),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _isBookmarked,
            builder: (context, bookmarked, _) {
              return IconButton(
                icon: Icon(
                  bookmarked ? Icons.bookmark : Icons.bookmark_outline,
                ),
                tooltip:
                    bookmarked
                        ? l10n.viewerBookmarkClearTooltip
                        : l10n.viewerBookmarkSaveTooltip,
                onPressed: _toggleBookmark,
              );
            },
          ),
        ],
      ),
      // `IgnorePointer` guard because `AnimatedScale(scale: 0)` still
      // participates in hit-testing at its original bounds — without
      // the guard, invisible taps near the bottom-right of the
      // viewport would fire `_scrollToTop` even when the FAB is not
      // supposed to be there.
      floatingActionButton: IgnorePointer(
        ignoring: !_showBackToTop,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: _showBackToTop ? 1 : 0,
          child: FloatingActionButton.small(
            tooltip: l10n.viewerBackToTopTooltip,
            onPressed: _scrollToTop,
            child: const Icon(Icons.arrow_upward),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
            onRetry:
                () => ref.invalidate(viewerDocumentProvider(widget.documentId)),
          );
        },
        data: (document) {
          // Try to restore the saved position the first time we
          // reach the data state for this document. The flag inside
          // [_maybeRestoreReadingPosition] makes the body re-build
          // safe across rebuilds triggered by scroll listeners.
          _maybeRestoreReadingPosition();
          return MarkdownView(
            document: document,
            controller: _scrollController,
          );
        },
      ),
    );
  }

  String _titleFor(DocumentId id, String fallback) {
    final basename = p.basename(id.value);
    return basename.isEmpty ? fallback : basename;
  }
}
