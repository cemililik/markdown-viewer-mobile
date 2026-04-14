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
import 'package:markdown_viewer/features/viewer/presentation/widgets/in_doc_search_bar.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/markdown_view.dart';
import 'package:markdown_viewer/features/viewer/presentation/widgets/toc_drawer.dart';
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

  /// GlobalKeys attached to each rendered top-level block. Keyed
  /// by block index. Populated lazily on the first data state
  /// and re-allocated if the provider later returns a document
  /// with a different block count (e.g. after a retry that
  /// reloaded a changed file on disk). The TOC drawer + in-doc
  /// search both look up keys here before driving
  /// `Scrollable.ensureVisible`.
  final Map<int, GlobalKey> _blockKeys = {};
  int _blockKeysLength = 0;

  /// In-document search state. `_searchActive` flips the AppBar
  /// title slot between the document basename and the
  /// [InDocSearchBar]; `_searchMatches` is a flat list of
  /// source character offsets that match the current query,
  /// used to drive the counter and prev/next chevrons; the
  /// text controller + focus node are owned here so the field
  /// survives rebuilds while the viewer loads more bytes.
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchActive = false;
  List<int> _searchMatches = const <int>[];
  int _currentMatchIndex = 0;

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
    _searchController.dispose();
    _searchFocusNode.dispose();
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

  /// Makes sure there is exactly one [GlobalKey] per top-level
  /// block in [document]. Called from the data branch of
  /// `build` so the keys stay aligned with whatever the parser
  /// last returned — a retry that reloaded a shorter file
  /// would otherwise leave dangling keys pointing at widgets
  /// that no longer exist.
  void _ensureBlockKeys(Document document) {
    final needed = document.topLevelBlockCount;
    if (_blockKeysLength == needed) return;
    _blockKeys.clear();
    for (var i = 0; i < needed; i += 1) {
      _blockKeys[i] = GlobalKey(debugLabel: 'doc-block-$i');
    }
    _blockKeysLength = needed;
  }

  /// Animates the scroll so the block the heading sits in is
  /// pinned near the top of the viewport. Uses
  /// `Scrollable.ensureVisible` against the GlobalKey wrapped
  /// around that block's rendered widget, so the jump is
  /// pixel-perfect without any offset measuring on our side.
  void _scrollToHeading(HeadingRef heading) {
    final key = _blockKeys[heading.blockIndex];
    final target = key?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      // `alignment: 0` pins the heading at the top of the
      // visible area, mirroring how browser anchor navigation
      // feels. `alignmentPolicy: keepVisibleAtEnd` would glue
      // the bottom of the block to the bottom of the viewport,
      // which is the wrong reading flow for a "jump to
      // section" gesture.
      alignment: 0,
    );
  }

  /// Enters in-document search mode: swaps the AppBar title
  /// for the [InDocSearchBar] and focuses the text field so
  /// the keyboard comes up on the next frame.
  void _openSearch() {
    setState(() {
      _searchActive = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  /// Exits search mode, clears the query, and drops the match
  /// list so the next open starts from a clean slate.
  void _closeSearch() {
    setState(() {
      _searchActive = false;
      _searchController.clear();
      _searchMatches = const <int>[];
      _currentMatchIndex = 0;
    });
    _searchFocusNode.unfocus();
  }

  /// Recomputes the match list for [query] against the active
  /// document's source. Case-insensitive substring scan — we
  /// do not support regex in v1 because the input is a single
  /// compact AppBar field and users expect plain-text search.
  void _onSearchQueryChanged(String query, Document document) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchMatches = const <int>[];
        _currentMatchIndex = 0;
      });
      return;
    }
    final matches = <int>[];
    final lowerSource = document.source.toLowerCase();
    final lowerQuery = trimmed.toLowerCase();
    var index = lowerSource.indexOf(lowerQuery);
    while (index != -1) {
      matches.add(index);
      index = lowerSource.indexOf(lowerQuery, index + 1);
    }
    setState(() {
      _searchMatches = matches;
      _currentMatchIndex = 0;
    });
    if (matches.isNotEmpty) {
      _jumpToMatch(matches.first, document);
    }
  }

  /// Advances the current match index and scrolls to the new
  /// match. Wraps around so the last match's "next" jumps back
  /// to the first — familiar from every browser find bar.
  void _nextMatch(Document document) {
    if (_searchMatches.isEmpty) return;
    final nextIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    setState(() => _currentMatchIndex = nextIndex);
    _jumpToMatch(_searchMatches[nextIndex], document);
  }

  void _previousMatch(Document document) {
    if (_searchMatches.isEmpty) return;
    final length = _searchMatches.length;
    final prevIndex = (_currentMatchIndex - 1 + length) % length;
    setState(() => _currentMatchIndex = prevIndex);
    _jumpToMatch(_searchMatches[prevIndex], document);
  }

  /// Builds the `PreferredSize` bar that sits under the AppBar
  /// while search is active. Shows "line N" and the line's
  /// text with the matched substring highlighted so the user
  /// sees the exact context for the current match — the
  /// scroll landing is approximate, the context hint is not.
  PreferredSizeWidget _buildSearchContextHint(Document document) {
    final query = _searchController.text;
    final offset = _searchMatches[_currentMatchIndex];
    final ctx = _matchContext(
      source: document.source,
      offset: offset,
      queryLength: query.length,
    );
    return PreferredSize(
      preferredSize: const Size.fromHeight(36),
      child: _SearchContextHint(context: ctx),
    );
  }

  /// Returns the line in `document.source` that contains
  /// [offset], along with the start/end positions of the match
  /// relative to the line start. Used by the search context
  /// hint under the AppBar to show the user exactly which line
  /// the current match lives on, with the matched substring
  /// emphasised — the scroll landing is approximate, so the
  /// hint compensates by providing the precise textual
  /// context.
  ({String lineText, int startInLine, int endInLine, int lineIndex})?
  _matchContext({
    required String source,
    required int offset,
    required int queryLength,
  }) {
    if (offset < 0 || offset >= source.length) return null;
    var lineStart = 0;
    var lineIndex = 0;
    for (var i = 0; i < offset; i += 1) {
      if (source.codeUnitAt(i) == 0x0A) {
        lineIndex += 1;
        lineStart = i + 1;
      }
    }
    var lineEnd = source.indexOf('\n', offset);
    if (lineEnd == -1) lineEnd = source.length;
    final lineText = source.substring(lineStart, lineEnd);
    final startInLine = offset - lineStart;
    final endInLine = (startInLine + queryLength).clamp(0, lineText.length);
    return (
      lineText: lineText,
      startInLine: startInLine,
      endInLine: endInLine,
      lineIndex: lineIndex,
    );
  }

  /// Scrolls to an approximate offset based on the fraction of
  /// the matched position in the source. Search match offsets
  /// are character positions in the source string; we convert
  /// to a fraction of `document.source.length` and apply that
  /// fraction to `maxScrollExtent`.
  ///
  /// This is imprecise — a match in the first character of a
  /// huge code block will land slightly off the block's
  /// rendered top — but it is honest: the user sees the match
  /// counter, the context hint under the AppBar, and the
  /// approximate landing. Inline match highlighting inside the
  /// rendered widget tree would require forking
  /// `markdown_widget`'s text builder, tracked as a follow-up.
  void _jumpToMatch(int sourceOffset, Document document) {
    if (!_scrollController.hasClients) return;
    final total = document.source.length;
    if (total == 0) return;
    final maxOffset = _scrollController.position.maxScrollExtent;
    final fraction = sourceOffset / total;
    final target = (fraction * maxOffset).clamp(0.0, maxOffset);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
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
    final readingSettings = ref.watch(readingSettingsControllerProvider);

    // The TOC drawer needs a non-null document to render. In
    // the loading / error states there is nothing to list, so
    // we fall back to a tiny placeholder drawer that shows the
    // localized "No headings" empty state. Wiring it here
    // avoids a conditional `endDrawer` on the Scaffold, which
    // would retear the drawer animation between state flips.
    final dataDocument = async.asData?.value;

    return Scaffold(
      appBar: AppBar(
        // Explicit leading button: on a push-navigated viewer the
        // default `leading` from [AppBar] would already show one,
        // but deep links (`/viewer?path=…`) land directly on this
        // route with an empty stack. `canPop()` falls through to a
        // `go` back to the library so the user is never stranded.
        // Hidden while search mode is active so the close button
        // in the search bar owns the only dismissal path.
        leading:
            _searchActive
                ? null
                : BackButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(LibraryRoute.location());
                    }
                  },
                ),
        // AnimatedSwitcher flips the title slot between the
        // document basename and the in-doc search field so the
        // transition looks intentional rather than a jarring
        // rebuild. Duration matches Material 3's small-component
        // transition guidance.
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child:
              _searchActive && dataDocument != null
                  ? InDocSearchBar(
                    key: const ValueKey('search-bar'),
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    matchCount: _searchMatches.length,
                    currentMatchIndex: _currentMatchIndex,
                    onQueryChanged:
                        (query) => _onSearchQueryChanged(query, dataDocument),
                    onPrevious: () => _previousMatch(dataDocument),
                    onNext: () => _nextMatch(dataDocument),
                    onClose: _closeSearch,
                  )
                  : Text(
                    key: const ValueKey('doc-title'),
                    _titleFor(widget.documentId, l10n.viewerUnnamedDocument),
                  ),
        ),
        actions:
            _searchActive
                ? const <Widget>[]
                : [
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: l10n.viewerSearchOpenTooltip,
                    onPressed: dataDocument == null ? null : _openSearch,
                  ),
                  Builder(
                    builder:
                        (context) => IconButton(
                          icon: const Icon(Icons.format_list_bulleted),
                          tooltip: l10n.viewerTocOpenTooltip,
                          onPressed:
                              dataDocument == null
                                  ? null
                                  : () => Scaffold.of(context).openEndDrawer(),
                        ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isBookmarked,
                    builder: (context, bookmarked, _) {
                      // `IconButton` does not expose an
                      // `onLongPress`, and wrapping it in a
                      // `GestureDetector` loses long-press events
                      // to the inner tap recognizer inside the
                      // gesture arena. The reliable fix is an
                      // `InkResponse` sized to the standard
                      // 48×48 dp AppBar action touch target with
                      // both `onTap` and `onLongPress` wired. A
                      // surrounding `Tooltip` preserves the
                      // hover/long-press accessibility affordance
                      // that IconButton normally provides.
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
                              bookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_outline,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
        // Context hint shown under the AppBar while search mode
        // is active: a compact line preview with the matched
        // substring bolded + highlighted so the user can
        // actually see which match they're cycling through,
        // even though the scroll landing is approximate.
        bottom:
            (_searchActive &&
                    dataDocument != null &&
                    _searchMatches.isNotEmpty &&
                    _searchController.text.isNotEmpty)
                ? _buildSearchContextHint(dataDocument)
                : null,
      ),
      endDrawer:
          dataDocument == null
              ? null
              : TocDrawer(
                document: dataDocument,
                onHeadingSelected: _scrollToHeading,
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
          // Make sure every top-level block has a GlobalKey so the
          // TOC drawer + in-doc search can land on it via
          // `Scrollable.ensureVisible`. Recomputed only when the
          // block count changes, so typical live rebuilds reuse
          // the same keys and the widget tree stays stable.
          _ensureBlockKeys(document);
          return MarkdownView(
            document: document,
            controller: _scrollController,
            blockKeys: _blockKeys,
            readingSettings: readingSettings,
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

/// Contextual line preview shown under the AppBar while search
/// is active. Renders the line containing the current match
/// with the matched substring highlighted (bold + filled
/// secondary-container background). When the line is very
/// long, the widget clips ~32 characters before the match and
/// ~48 after, joined with ellipses so the matched word stays
/// centred in the visible window — the user always sees
/// context on both sides of the match.
class _SearchContextHint extends StatelessWidget {
  const _SearchContextHint({required this.context});

  /// Nullable so the widget can render an empty placeholder
  /// without an extra conditional at the call site. `null`
  /// falls through to a zero-height bar — the caller should
  /// only mount the widget when a context actually exists.
  final ({String lineText, int startInLine, int endInLine, int lineIndex})?
  context;

  static const int _preWindow = 32;
  static const int _postWindow = 48;

  @override
  Widget build(BuildContext buildContext) {
    final theme = Theme.of(buildContext);
    final scheme = theme.colorScheme;
    final ctx = context;
    if (ctx == null) {
      return Container(height: 36, color: scheme.surfaceContainerHigh);
    }
    final lineText = ctx.lineText;
    final start = ctx.startInLine.clamp(0, lineText.length);
    final end = ctx.endInLine.clamp(start, lineText.length);

    final beforeRaw = lineText.substring(0, start);
    final match = lineText.substring(start, end);
    final afterRaw = lineText.substring(end);

    final before =
        beforeRaw.length > _preWindow
            ? '…${beforeRaw.substring(beforeRaw.length - _preWindow)}'
            : beforeRaw;
    final after =
        afterRaw.length > _postWindow
            ? '${afterRaw.substring(0, _postWindow)}…'
            : afterRaw;

    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: RichText(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(
              text: 'L${ctx.lineIndex + 1}  ',
              style: baseStyle?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            TextSpan(text: before),
            TextSpan(
              text: match,
              style: baseStyle?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSecondaryContainer,
                backgroundColor: scheme.secondaryContainer,
              ),
            ),
            TextSpan(text: after),
          ],
        ),
      ),
    );
  }
}
