import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_viewer/app/router.dart';
import 'package:markdown_viewer/core/errors/failure.dart';
import 'package:markdown_viewer/core/l10n/build_context_l10n.dart';
import 'package:markdown_viewer/core/widgets/error_view.dart';
import 'package:markdown_viewer/core/widgets/loading_view.dart';
import 'package:markdown_viewer/features/library/application/preview_extractor.dart';
import 'package:markdown_viewer/features/library/application/recent_documents_provider.dart';
import 'package:markdown_viewer/features/settings/application/settings_providers.dart';
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
      _animateToSavedPosition(saved);
      _showLocalizedSnackBar((l10n) => l10n.viewerResumedFromBookmark);
    });
  }

  /// Saves the current scroll offset as the reading-position
  /// bookmark, whether or not one already exists for this
  /// document. Tap semantics are deliberately "do what I mean":
  /// the user taps to say "remember where I am right now", and
  /// the button no longer acts as a toggle — removal is a
  /// long-press affordance handled by [_showBookmarkMenu].
  ///
  /// The snackbar wording reflects "saved for the first time on
  /// this document" vs "updated over a previous save" by checking
  /// the store before writing. A separate one-shot coach mark
  /// (`viewerBookmarkLongPressHint`) is appended the very first
  /// time the user ever saves a bookmark — across all
  /// documents — so they learn that long-press opens the remove
  /// menu, then never see the hint again.
  Future<void> _saveBookmark() async {
    final store = ref.read(readingPositionStoreProvider);
    final settingsStore = ref.read(settingsStoreProvider);
    final hadPrevious = store.read(widget.documentId) != null;
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
    if (!mounted) return;

    final firstEver = !settingsStore.readHasSeenBookmarkHint();
    if (firstEver) {
      // Fire-and-forget — the next save does not need to wait
      // on the flag landing in prefs to show the shorter
      // confirmation.
      settingsStore.markBookmarkHintSeen().ignore();
    }
    _showBookmarkSaveConfirmation(
      hadPrevious: hadPrevious,
      includeHint: firstEver,
    );
  }

  /// Shows the Save/Update confirmation snackbar. When
  /// [includeHint] is true a second line teaching the long-press
  /// remove affordance is appended and the duration bumps from
  /// 3 s to 5 s so the user has time to actually read it.
  void _showBookmarkSaveConfirmation({
    required bool hadPrevious,
    required bool includeHint,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: Duration(seconds: includeHint ? 5 : 3),
        content: Builder(
          builder: (context) {
            final l10n = context.l10n;
            final headline =
                hadPrevious
                    ? l10n.viewerBookmarkUpdated
                    : l10n.viewerBookmarkSaved;
            if (!includeHint) {
              return Text(headline);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(headline),
                const SizedBox(height: 4),
                Text(
                  l10n.viewerBookmarkLongPressHint,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Opens the bookmark long-press bottom sheet with two
  /// actions: animate back to the saved position, or clear the
  /// saved position entirely. No-op when no bookmark has been
  /// saved yet — the sheet would only show a disabled "Go to"
  /// and a pointless "Remove", so we short-circuit with a
  /// single-line save snackbar instead, mirroring the tap path.
  Future<void> _showBookmarkMenu() async {
    final store = ref.read(readingPositionStoreProvider);
    final saved = store.read(widget.documentId);
    if (saved == null) {
      await _saveBookmark();
      return;
    }
    final choice = await showModalBottomSheet<_BookmarkMenuAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.bookmark_outlined),
                title: Text(l10n.viewerBookmarkMenuGoTo),
                onTap:
                    () => Navigator.of(
                      sheetContext,
                    ).pop(_BookmarkMenuAction.goTo),
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_remove_outlined),
                title: Text(l10n.viewerBookmarkMenuRemove),
                onTap:
                    () => Navigator.of(
                      sheetContext,
                    ).pop(_BookmarkMenuAction.remove),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _BookmarkMenuAction.goTo:
        _animateToSavedPosition(saved);
      case _BookmarkMenuAction.remove:
        _isBookmarked.value = false;
        await store.clear(widget.documentId);
        if (!mounted) return;
        _showLocalizedSnackBar((l10n) => l10n.viewerBookmarkCleared);
    }
  }

  /// Animates the scroll back to [position]. Shared by the
  /// long-press menu and the first-frame auto-restore so the
  /// two paths land on the same motion.
  void _animateToSavedPosition(ReadingPosition position) {
    if (!_scrollController.hasClients) return;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final target = position.offset.clamp(0.0, maxOffset);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
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
    // Touch the recent-documents list as soon as the document
    // transitions to the data state. Listening here (rather than
    // hooking into `LibraryScreen._pickAndOpenFile`) means every
    // entry point — file picker, deep links via go_router,
    // future folder explorer, even in-doc cross-links — records
    // through one funnel.
    ref.listen<AsyncValue<Document>>(
      viewerDocumentProvider(widget.documentId),
      (previous, next) {
        next.whenData((document) {
          ref
              .read(recentDocumentsControllerProvider.notifier)
              .touch(
                widget.documentId,
                preview: extractPreviewSnippet(document.source),
              );
        });
      },
    );
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
              // `IconButton` does not expose an `onLongPress`,
              // and wrapping it in a `GestureDetector` loses
              // long-press events to the inner tap recognizer
              // inside the gesture arena. The reliable fix is
              // an `InkResponse` sized to the standard 48×48 dp
              // AppBar action touch target with both `onTap`
              // and `onLongPress` wired. A surrounding
              // `Tooltip` preserves the hover/long-press
              // accessibility affordance that IconButton
              // normally provides.
              return Tooltip(
                message: l10n.viewerBookmarkSaveTooltip,
                child: InkResponse(
                  onTap: _saveBookmark,
                  onLongPress: _showBookmarkMenu,
                  radius: 24,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      bookmarked ? Icons.bookmark : Icons.bookmark_outline,
                    ),
                  ),
                ),
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

/// Two-entry menu surfaced by the bookmark long-press. Hoisted
/// out of the state class so the bottom sheet result type is a
/// plain enum and not a nested generic.
enum _BookmarkMenuAction { goTo, remove }
